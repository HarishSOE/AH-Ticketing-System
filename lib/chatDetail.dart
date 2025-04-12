import 'dart:async';

import 'package:ahticketing/AppServices/AppService.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ChatDetailScreen extends StatefulWidget {
  final String waId;
  final String contactName;
  final dynamic latestMessage;
  final String selectWati;

  const ChatDetailScreen({
    Key? key,
    required this.waId,
    required this.contactName,
    required this.latestMessage,
    required this.selectWati,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  
  Map mapWatiTemplate = {};
  Map replayMap = {};

  List<dynamic> templates = [];
  List<Map<String, dynamic>> allMessages = []; // Store all messages
  List<Map<String, dynamic>> displayedMessages = []; // Messages currently displayed
  List<Map<String, dynamic>> searchResults = []; // Search results
  
  bool isLoading = true;
  bool isLoadingMore = false;
  bool isChatExpired = false;
  bool isSearching = false;
  
  // Pagination
  final int pageSize = 50;
  DocumentSnapshot? lastDocument;
  bool hasMoreMessages = true;
  
  // Chat expiration
  DateTime? lastMessageTime;
  Timer? expiryTimer;
  String expiryTimeDisplay = "";
  final int chatExpiryHours = 24; // 24 hours expiry

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    fetchInitialMessages();
    AppService().fetchTemplates().then((value) {
      templates = value['templates'];
      mapWatiTemplate = value['mapWatiTemplate'];
    });
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _messagesSubscription?.cancel();
    expiryTimer?.cancel();
    super.dispose();
  }
  
  void _onScroll() {
    // Load more messages when user scrolls to the top
    if (_scrollController.position.pixels <= _scrollController.position.minScrollExtent + 200 && 
        !isLoadingMore && 
        hasMoreMessages &&
        !isSearching) {
      _loadMoreMessages();
    }
  }

  void fetchInitialMessages() {
    setState(() {
      isLoading = true;
      allMessages = [];
      displayedMessages = [];
      searchResults = [];
    });

    try {
      // Create initial query for the most recent 50 messages
      Query query = firestore
          .collection("wati logs")
          .where("waId", isEqualTo: widget.waId)
          .orderBy("date", descending: true)
          .limit(pageSize);
      
      _messagesSubscription = query.snapshots().listen(
        (QuerySnapshot snapshot) {
          print('TOTAL CHATS FOUND: ${snapshot.docs.length}');
          
          if (snapshot.docs.isNotEmpty) {
            // Save the last document for pagination
            lastDocument = snapshot.docs.last;
            hasMoreMessages = snapshot.docs.length == pageSize;
            
            List<Map<String, dynamic>> chatMessages = [];
            Map<String, String> messageStatusMap = {};
            replayMap = {};
            // First pass: Identify message status updates
            for (var doc in snapshot.docs) {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              String eventType = data['eventType'];
              String whatsappMessageId = data['whatsappMessageId'] ?? '';

              // Track message status updates
              if(widget.selectWati == 'All Chats'){
                if (eventType == 'sentMessageREAD' && whatsappMessageId.isNotEmpty) {
                  messageStatusMap[whatsappMessageId] = 'READ';
                }
                if (eventType == 'sentMessageDELIVERED_v2' && whatsappMessageId.isNotEmpty) {
                  // Only set to DELIVERED if not already READ
                  if (messageStatusMap[whatsappMessageId] != 'READ') {
                    messageStatusMap[whatsappMessageId] = 'DELIVERED';
                  }
                }
                if (eventType == 'templateMessageFailed' && whatsappMessageId.isNotEmpty) {
                  messageStatusMap[whatsappMessageId] = 'FAILED';
                }

                if(data['replyContextId'] != null && data['replyContextId'] != ""){
                  replayMap[whatsappMessageId] = data['text'];
                }

                if (eventType == 'templateMessageSent_v2' || 
                    eventType == 'message' || 
                    eventType == 'sessionMessageSent' || 
                    (eventType == 'sentMessageDELIVERED_v2' && data['type'] == 'text')) {
                  
                  // Update status if available
                  if (whatsappMessageId.isNotEmpty && messageStatusMap.containsKey(whatsappMessageId)) {
                    data['statusString'] = messageStatusMap[whatsappMessageId];
                  }
                  
                  chatMessages.add(data);
                }
              }else{
                if(data['watiName'] == widget.selectWati){

                  if (eventType == 'sentMessageREAD' && whatsappMessageId.isNotEmpty) {
                    messageStatusMap[whatsappMessageId] = 'READ';
                  }

                  if (eventType == 'sentMessageDELIVERED_v2' && whatsappMessageId.isNotEmpty) {
                    // Only set to DELIVERED if not already READ
                    if (messageStatusMap[whatsappMessageId] != 'READ') {
                      messageStatusMap[whatsappMessageId] = 'DELIVERED';
                    }
                  }
                   if (eventType == 'templateMessageFailed' && whatsappMessageId.isNotEmpty) {
                    messageStatusMap[whatsappMessageId] = 'FAILED';
                  }

                  if(whatsappMessageId.isNotEmpty){
                    replayMap[whatsappMessageId] = data;
                  }

                  if (eventType == 'templateMessageSent_v2' || 
                      eventType == 'message' || 
                      eventType == 'sessionMessageSent' || 
                      (eventType == 'sentMessageDELIVERED_v2' && data['type'] == 'text')) {
                    
                    // Update status if available
                    if (whatsappMessageId.isNotEmpty && messageStatusMap.containsKey(whatsappMessageId)) {
                      data['statusString'] = messageStatusMap[whatsappMessageId];
                    }
                    
                    chatMessages.add(data);
                  }
                }
                
              }

            }
            print('REPLAY${replayMap}');
            
            setState(() {
              allMessages = chatMessages;
              displayedMessages = chatMessages;
              isLoading = false;
              
              // Update chat expiry time based on the newest message
              if (chatMessages.isNotEmpty) {
                Timestamp newest = chatMessages.first['date'];
                updateChatExpiry(newest.toDate());
              }
            });
          } else {
            setState(() {
              allMessages = [];
              displayedMessages = [];
              isLoading = false;
            });
          }
        },
        onError: (error) {
          print('Error in messages subscription: $error');
          setState(() {
            isLoading = false;
          });
        }
      );
    } catch (error) {
      print('Error setting up messages subscription: $error');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  Future<void> _loadMoreMessages() async {
    if (!hasMoreMessages || lastDocument == null) return;
    
    setState(() {
      isLoadingMore = true;
    });
    
    try {
      // Query for older messages
      QuerySnapshot snapshot = await firestore
          .collection("wati logs")
          .where("waId", isEqualTo: widget.waId)
          .orderBy("date", descending: true)
          .startAfterDocument(lastDocument!)
          .limit(pageSize)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        // Update the last document for next pagination
        lastDocument = snapshot.docs.last;
        hasMoreMessages = snapshot.docs.length == pageSize;
        
        List<Map<String, dynamic>> oldMessages = [];
        Map<String, String> messageStatusMap = {};
        
        // First pass: Identify message status updates
        for (var doc in snapshot.docs) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          String eventType = data['eventType'];
          String whatsappMessageId = data['whatsappMessageId'] ?? '';

          if(widget.selectWati == 'All Chats'){

            // Track message status updates
            if (eventType == 'sentMessageREAD' && whatsappMessageId.isNotEmpty) {
              messageStatusMap[whatsappMessageId] = 'READ';
            }
            if (eventType == 'sentMessageDELIVERED_v2' && whatsappMessageId.isNotEmpty) {
              // Only set to DELIVERED if not already READ
              if (messageStatusMap[whatsappMessageId] != 'READ') {
                messageStatusMap[whatsappMessageId] = 'DELIVERED';
              }
            }
            if(eventType == 'templateMessageFailed' && whatsappMessageId.isNotEmpty) {
              messageStatusMap[whatsappMessageId] = 'FAILED';
            }

            if(data['replyContextId'] != null && data['replyContextId'] != ""){
              replayMap[whatsappMessageId] = data;
            }
            
            // Only include displayable message types
            if (eventType == 'templateMessageSent_v2' || 
                eventType == 'message' || 
                eventType == 'sessionMessageSent' || 
                (eventType == 'sentMessageDELIVERED_v2' && data['type'] == 'text')) {
              
              // Update status if available
              if (whatsappMessageId.isNotEmpty && messageStatusMap.containsKey(whatsappMessageId)) {
                data['statusString'] = messageStatusMap[whatsappMessageId];
              }
              
              oldMessages.add(data);
            }
          }
          else {
            if(data['watiName'] == widget.selectWati){
              // Track message status updates
              if (eventType == 'sentMessageREAD' && whatsappMessageId.isNotEmpty) {
                messageStatusMap[whatsappMessageId] = 'READ';
              }
              if (eventType == 'sentMessageDELIVERED_v2' && whatsappMessageId.isNotEmpty) {
                // Only set to DELIVERED if not already READ
                if (messageStatusMap[whatsappMessageId] != 'READ') {
                  messageStatusMap[whatsappMessageId] = 'DELIVERED';
                }
              }
              if(eventType == 'templateMessageFailed' && whatsappMessageId.isNotEmpty) {
                messageStatusMap[whatsappMessageId] = 'FAILED';
              }

              if(data['replyContextId'] != null && data['replyContextId'] != ""){
                replayMap[whatsappMessageId] = data;
              }
              
              // Only include displayable message types
              if (eventType == 'templateMessageSent_v2' || 
                  eventType == 'message' || 
                  eventType == 'sessionMessageSent' || 
                  (eventType == 'sentMessageDELIVERED_v2' && data['type'] == 'text')) {
                
                // Update status if available
                if (whatsappMessageId.isNotEmpty && messageStatusMap.containsKey(whatsappMessageId)) {
                  data['statusString'] = messageStatusMap[whatsappMessageId];
                }
                
                oldMessages.add(data);
              }
            }
          }
        }
        
        setState(() {
          allMessages.addAll(oldMessages);
          displayedMessages.addAll(oldMessages);
          isLoadingMore = false;
        });
      } else {
        setState(() {
          hasMoreMessages = false;
          isLoadingMore = false;
        });
      }
    } catch (error) {
      print('Error loading more messages: $error');
      setState(() {
        isLoadingMore = false;
      });
    }
  }

  void updateChatExpiry(DateTime messageTime) {
    // Cancel any existing timer
    expiryTimer?.cancel();
    
    // Set the last message time
    lastMessageTime = messageTime;
    
    // Calculate expiry time (24 hours after the last message)
    final expiryTime = messageTime.add(Duration(hours: chatExpiryHours));
    final now = DateTime.now();
    
    // Check if chat is already expired
    if (now.isAfter(expiryTime)) {
      setState(() {
        isChatExpired = true;
        expiryTimeDisplay = "Expired";
      });
      return;
    }
    
    // Chat is not expired, set up timer to update the remaining time
    setState(() {
      isChatExpired = false;
    });
    
    // Update immediately then set timer
    _updateExpiryTimeDisplay(expiryTime);
    
    // Set timer to update every minute
    expiryTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      _updateExpiryTimeDisplay(expiryTime);
    });
  }
  
  void _updateExpiryTimeDisplay(DateTime expiryTime) {
    final now = DateTime.now();
    final difference = expiryTime.difference(now);
    
    if (difference.isNegative) {
      // Chat has expired
      setState(() {
        isChatExpired = true;
        expiryTimeDisplay = "Expired";
      });
      expiryTimer?.cancel();
      return;
    }
    
    // Format the remaining time
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    
    setState(() {
      expiryTimeDisplay = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
    });
  }
  
  void _searchMessages(String query) {
    if (query.isEmpty) {
      setState(() {
        isSearching = false;
        displayedMessages = allMessages;
      });
      return;
    }
    
    setState(() {
      isSearching = true;
      searchResults = allMessages.where((message) {
        String messageText = message['text'] ?? '';
        return messageText.toLowerCase().contains(query.toLowerCase());
      }).toList();
      
      displayedMessages = searchResults;
    });
  }
  
  void _toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) {
        _searchController.clear();
        displayedMessages = allMessages;
      }
    });
  }
  
  String formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    
    // Format like "04/04 12:44 PM" as in the screenshot
    return DateFormat('MM/dd hh:mm a').format(dateTime);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE5DDD5), // WhatsApp chat background color
      appBar: AppBar(
        backgroundColor: Color(0xFFEDEDED), // Light gray header background
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        titleSpacing: 0,
        title: isSearching
            ? _buildSearchField()
            : Row(
                children: [
                  // Contact avatar
                  CircleAvatar(
                    backgroundColor: Color(0xFF8000FF),
                    radius: 20,
                    child: Text(
                      widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.contactName,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color.fromARGB(255, 232, 210, 255),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Open',
                                style: TextStyle(
                                  color: Color(0xFF8000FF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.fiber_manual_record, size: 6, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              'Bot',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search, color: Colors.black),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat expiry indicator
          if (!isChatExpired && !isSearching)
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, size: 18, color: Color(0xFF8000FF),),
                  SizedBox(width: 6),
                  Text(
                    'Chat expires in $expiryTimeDisplay',
                    style: TextStyle(
                      color: Color(0xFF8000FF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          
          // Search results count
          if (isSearching)
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 18, color: Color(0xFF8000FF),),
                  SizedBox(width: 6),
                  Text(
                    '${searchResults.length} message${searchResults.length != 1 ? 's' : ''} found',
                    style: TextStyle(
                      color: Color(0xFF8000FF),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
          // Messages list
          Expanded(
            child: isLoading
              ? Center(child: CircularProgressIndicator(color: Color(0xFF8000FF)))
              : displayedMessages.isEmpty
                ? Center(child: Text(isSearching ? 'No messages match your search' : 'No messages found'))
                : Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        itemCount: displayedMessages.length + (isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show loading indicator at the top
                          if (isLoadingMore && index == displayedMessages.length) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(color: Color(0xFF8000FF)),
                              ),
                            );
                          }
                          
                          final message = displayedMessages[index];
                          
                          // Check if this message is the chat expiry notice
                          if (message.containsKey('isChatExpiry') && message['isChatExpiry'] == true) {
                            return _buildChatExpiryNotice(message);
                          }
                          
                          final bool isOwner = message['owner'] ?? false;
                          final String messageType = message['type'] ?? 'text';
                          final String messageText = message['text'] ?? '';
                          final Timestamp created = message['date'];
                          final String status = message['statusString'] ?? '';
                          final String eventType = message['eventType'];
                          final bool isBot = eventType == 'templateMessageSent_v2';
                          final bool hasTitle = messageText.toLowerCase().contains('reminder');
                          final String title = hasTitle ? 'Reminder: Complete Your Self-Evolution Report' : '';
                          
                          // Highlight search text if searching
                          final bool shouldHighlight = isSearching && _searchController.text.isNotEmpty;
                          
                          return _buildMessageItem(
                            isOwner: isOwner,
                            messageType: messageType, 
                            messageText: messageText,
                            timestamp: created,
                            status: status,
                            eventType: eventType,
                            messageData: message,
                            isBot: isBot,
                            title: title,
                            highlightText: shouldHighlight ? _searchController.text : null,
                            replayMap : replayMap
                          );
                        },
                      ),
                      
                      // "Load more" button when at top
                      // if (!hasMoreMessages && !isSearching)
                      //   Positioned(
                      //     top: 0,
                      //     left: 0,
                      //     right: 0,
                      //     child: Container(
                      //       padding: EdgeInsets.symmetric(vertical: 8),
                      //       color: Colors.grey.withOpacity(0.7),
                      //       child: Center(
                      //         child: Text(
                      //           'No more messages to load',
                      //           style: TextStyle(
                      //             color: Colors.white,
                      //             fontSize: 12,
                      //           ),
                      //         ),
                      //       ),
                      //     ),
                      //   ),
                    ],
                  ),
          ),
          
          // Input field (disabled in this view-only implementation)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey.shade600),
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    enabled: false, // View only
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Color(0xFF8000FF),
                  child: Icon(Icons.mic, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search messages...',
        hintStyle: TextStyle(color: Colors.grey.shade500),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      style: TextStyle(
        color: Colors.black,
        fontSize: 16,
      ),
      onChanged: _searchMessages,
    );
  }
  
  Widget _buildChatExpiryNotice(Map<String, dynamic> message) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 16, horizontal: 30),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        message['text'] ?? 'The chat has expired\n(after 24 hours of last received message)',
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
  
  Widget _buildMessageItem({
    required bool isOwner,
    required String messageType,
    required String messageText,
    required Timestamp timestamp,
    required String status,
    required Map messageData,
    String eventType = '',
    bool isBot = false,
    String title = '',
    String? highlightText,
    required Map replayMap,
  }) {
    // Determine if message should be on the left side based on eventType
    final bool showOnLeft = eventType == 'message';
    
    // Determine message color based on message type and sender
    Color bubbleColor;
    if (status == 'FAILED' || eventType == 'templateMessageFailed') {
      bubbleColor = Colors.red.shade100; // Red for failed messages
    } else {
      // Match the WhatsApp style: custom purple for sent messages, white for received
      bubbleColor = showOnLeft ? Colors.white : Color.fromARGB(255, 173, 91, 255);
    }
    
    // Text color
    Color textColor = (showOnLeft) ? Colors.black : Colors.white;
    
    // Check if this is a reply message
    final bool isReply = messageData.containsKey('replyContextId') && messageData['replyContextId'] != null && messageData['replyContextId'].toString().isNotEmpty;
    
    // Get the replied message text if it exists
    String replyText = '';
    String replySenderName = '';

    if (isReply) {
      replyText = replayMap[messageData['replyContextId']] ?? 'Original message';
      replySenderName = messageData['replySender'] ?? '';
    }
    
    return Align(
      alignment: showOnLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(
          top: 4, 
          bottom: 4, 
          left: showOnLeft ? 12 : 60,
          right: showOnLeft ? 60 : 12,
        ),
        child: Column(
          crossAxisAlignment: showOnLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                  bottomLeft: showOnLeft ? Radius.circular(0) : Radius.circular(8),
                  bottomRight: showOnLeft ? Radius.circular(8) : Radius.circular(0),
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title for special messages (like reminders)
                  if (title.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  
                  // Reply context
                  if (isReply)
                    Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border(
                          left: BorderSide(
                            color: Colors.blue.shade300,
                            width: 4,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (replySenderName.isNotEmpty)
                            Text(
                              replySenderName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          SizedBox(height: replySenderName.isNotEmpty ? 2 : 0),
                          Text(
                            replyText,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  
                  // Message content with highlighting if needed
                  if (messageType == 'text' || messageType == 'template')
                    highlightText != null && messageText.toLowerCase().contains(highlightText.toLowerCase())
                      ? _buildHighlightedText(messageText, highlightText, textColor)
                      : Text(
                          messageText,
                          style: TextStyle(
                            fontSize: 14.5,
                            color: textColor,
                          ),
                        )
                  else if (messageType == 'image')
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Check if the message data contains an image URL
                          if (messageData.containsKey('mediaUrl') && messageData['mediaUrl'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                messageData['mediaUrl'],
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: double.infinity,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded / 
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        color: Color(0xFF8000FF),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: double.infinity,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(color: Colors.grey.shade700),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.image, size: 48, color: Colors.grey),
                              ),
                            ),
                          // Caption with highlighting if needed
                          if (messageText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: highlightText != null && messageText.toLowerCase().contains(highlightText.toLowerCase())
                                ? _buildHighlightedText(messageText, highlightText, textColor)
                                : Text(
                                    messageText,
                                    style: TextStyle(color: textColor),
                                  ),
                            ),
                        ],
                      ),
                    )
                  else if (messageType == 'document')
                    Container(
                      padding: EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insert_drive_file, size: 36, color: Colors.blue),
                          SizedBox(width: 8),
                          Flexible(
                            child: highlightText != null && messageText.toLowerCase().contains(highlightText.toLowerCase())
                              ? _buildHighlightedText(messageText, highlightText, textColor)
                              : Text(
                                  messageText.isNotEmpty ? messageText : 'Document',
                                  style: TextStyle(fontSize: 14, color: textColor),
                                ),
                          ),
                        ],
                      ),
                    )
                  else if(messageType == 'button')
                    Text(
                      messageText,
                      style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: textColor),
                    ),
                    
                  // Timestamp and read status - align to the right bottom
                  Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                formatTimestamp(timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: showOnLeft ? Colors.grey.shade600 : Colors.white,
                                ),
                              ),
                              SizedBox(width: 5,),
                              if(widget.selectWati == "All Chats" && messageData['watiName'] != null && messageData['watiName'] != "")
                              Container(
                                padding: EdgeInsets.only(top:2,bottom: 2,left: 5,right: 5),
                                decoration: BoxDecoration(
                                  color: Colors.purple[700],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  messageData['watiName'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              )

                            ],
                          ),
                          SizedBox(width: 3),
                          // Show WhatsApp check marks only for messages not on the left side
                          if (!showOnLeft && !isBot) // Only show status icons for outgoing non-bot messages
                            status == 'FAILED' 
                                ? Icon(
                                    Icons.error_outline,
                                    size: 12,
                                    color: Colors.red,
                                  )
                                : Icon(
                                    status == 'READ' 
                                        ? Icons.done_all 
                                        : status == 'DELIVERED' 
                                            ? Icons.done_all
                                            : Icons.done,
                                    size: 12,
                                    color: status == 'READ' ? Colors.blue : Colors.grey.shade600,
                                  ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHighlightedText(String text, String query, Color textColor) {
    final String lowerCaseText = text.toLowerCase();
    final String lowerCaseQuery = query.toLowerCase();
    
    if (!lowerCaseText.contains(lowerCaseQuery)) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 14.5,
          color: textColor,
        ),
      );
    }

    List<TextSpan> spans = [];
    int start = 0;
    int indexOfMatch;
    
    while (true) {
      indexOfMatch = lowerCaseText.indexOf(lowerCaseQuery, start);
      if (indexOfMatch == -1) {
        // No more matches
        spans.add(TextSpan(
          text: text.substring(start),
          style: TextStyle(
            fontSize: 14.5,
            color: textColor,
          ),
        ));
        break;
      }
      
      // Add text before the match
      if (indexOfMatch > start) {
        spans.add(TextSpan(
          text: text.substring(start, indexOfMatch),
          style: TextStyle(
            fontSize: 14.5,
            color: textColor,
          ),
        ));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + query.length),
        style: TextStyle(
          fontSize: 14.5,
          color: textColor,
          backgroundColor: Color(0xFFFFE082), // Light amber highlight
          fontWeight: FontWeight.bold,
        ),
      ));
      
      // Move start index after this match
      start = indexOfMatch + query.length;
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }
  
  String formatPhoneNumber(String phoneNumber) {
    // Basic formatting for phone numbers
    if (phoneNumber.length > 10) {
      // For numbers with country code
      String countryCode = phoneNumber.substring(0, phoneNumber.length - 10);
      String mainNumber = phoneNumber.substring(phoneNumber.length - 10);
      
      if (mainNumber.length >= 10) {
        return '+$countryCode ${mainNumber.substring(0, 3)} ${mainNumber.substring(3, 6)} ${mainNumber.substring(6)}';
      }
    }
    
    // Return as is if we can't format it
    return phoneNumber;
  }
  
  // Add an expiry message to the messages list
  void addExpiryMessage() {
    // Check if there's already an expiry message
    bool hasExpiryMessage = allMessages.any((message) => message.containsKey('isChatExpiry'));
    
    if (!hasExpiryMessage) {
      setState(() {
        Map<String, dynamic> expiryMessage = {
          'isChatExpiry': true,
          'text': 'The chat has been expired\n(after 24 hours of last received message)',
          'date': Timestamp.now(),
        };
        
        allMessages.insert(0, expiryMessage);
        displayedMessages.insert(0, expiryMessage);
      });
    }
  }
}

// import 'dart:async';
// import 'package:ahticketing/AppServices/AppService.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';

// class ChatDetailScreen extends StatefulWidget {
//   final String waId;
//   final String contactName;
//   final dynamic latestMessage;

//   const ChatDetailScreen({
//     Key? key,
//     required this.waId,
//     required this.contactName,
//     required this.latestMessage,
//   }) : super(key: key);

//   @override
//   State<ChatDetailScreen> createState() => _ChatDetailScreenState();
// }

// class _ChatDetailScreenState extends State<ChatDetailScreen> {
  
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//   StreamSubscription<QuerySnapshot>? _messagesSubscription;
  
//   Map mapWatiTemplate = {};
//   List<dynamic> templates = [];
//   List<Map<String, dynamic>> messages = [];
  
//   bool isLoading = true;
//   bool isChatExpired = false;
  
//   // Chat expiration
//   DateTime? lastMessageTime;
//   Timer? expiryTimer;
//   String expiryTimeDisplay = "";
//   final int chatExpiryHours = 24; // 24 hours expiry

//   @override
//   void initState() {
//     super.initState();
//     fetchMessages();
//     AppService().fetchTemplates().then((value) {
//       templates = value['templates'];
//       mapWatiTemplate = value['mapWatiTemplate'];
//     });
//   }
  
//   @override
//   void dispose() {
//     // Cancel the subscription when the widget is disposed
//     _messagesSubscription?.cancel();
//     expiryTimer?.cancel();
//     super.dispose();
//   }

//   void fetchMessages() {
//     setState(() {
//       isLoading = true;
//     });

//     try {
//       // Create a query for all messages for this contact
//       Query query = firestore.collection("wati logs").where("waId", isEqualTo: widget.waId).orderBy("date", descending: true);
      
//       // Subscribe to real-time updates
//       _messagesSubscription = query.snapshots().listen((QuerySnapshot snapshot) {
//           print('TOTAL CHATS FOUND: ${snapshot.docs.length}');
//           if (snapshot.docs.isNotEmpty) {
//             List<Map<String, dynamic>> chatMessages = [];
//             Map<String, String> messageStatusMap = {};
            
//             // First pass: Identify message status updates
//             for (var doc in snapshot.docs) {
//               Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
//               String eventType = data['eventType'];
//               String whatsappMessageId = data['whatsappMessageId'] ?? '';

//               // Track message status updates
//               if (eventType == 'sentMessageREAD' && whatsappMessageId.isNotEmpty) {
//                 messageStatusMap[whatsappMessageId] = 'READ';
//               } else if (eventType == 'sentMessageDELIVERED_v2' && whatsappMessageId.isNotEmpty) {
//                 // Only set to DELIVERED if not already READ
//                 if (messageStatusMap[whatsappMessageId] != 'READ') {
//                   messageStatusMap[whatsappMessageId] = 'DELIVERED';
//                 }
//               } else if (eventType == 'templateMessageFailed' && whatsappMessageId.isNotEmpty) {
//                 messageStatusMap[whatsappMessageId] = 'FAILED';
//               }

//               if (eventType == 'templateMessageSent_v2' || eventType == 'message' || eventType == 'sessionMessageSent' || (eventType == 'sentMessageDELIVERED_v2' && data['type'] == 'text')) {
//                 // Update status if available
//                 if (whatsappMessageId.isNotEmpty && messageStatusMap.containsKey(whatsappMessageId)) {
//                   data['statusString'] = messageStatusMap[whatsappMessageId];
//                 }
                
//                 chatMessages.add(data);
//               }
//             }
            
//             setState(() {
//               print('CHATMESSAGES: ${chatMessages.length}');
//               messages = chatMessages;
//               isLoading = false;
              
//               // Update chat expiry time based on the newest message
//               if (chatMessages.isNotEmpty) {
//                 Timestamp newest = chatMessages.last['date'];
//                 updateChatExpiry(newest.toDate());
//               }
//             });
//           } else {
//             setState(() {
//               messages = [];
//               isLoading = false;
//             });
//           }
//         },
//         onError: (error) {
//           print('Error in messages subscription: $error');
//           setState(() {
//             isLoading = false;
//           });
//         }
//       );
//     } catch (error) {
//       print('Error setting up messages subscription: $error');
//       setState(() {
//         isLoading = false;
//       });
//     }
//   }

//   void updateChatExpiry(DateTime messageTime) {
//     // Cancel any existing timer
//     expiryTimer?.cancel();
    
//     // Set the last message time
//     lastMessageTime = messageTime;
    
//     // Calculate expiry time (24 hours after the last message)
//     final expiryTime = messageTime.add(Duration(hours: chatExpiryHours));
//     final now = DateTime.now();
    
//     // Check if chat is already expired
//     if (now.isAfter(expiryTime)) {
//       setState(() {
//         isChatExpired = true;
//         expiryTimeDisplay = "Expired";
//       });
//       return;
//     }
    
//     // Chat is not expired, set up timer to update the remaining time
//     setState(() {
//       isChatExpired = false;
//     });
    
//     // Update immediately then set timer
//     _updateExpiryTimeDisplay(expiryTime);
    
//     // Set timer to update every minute
//     expiryTimer = Timer.periodic(Duration(minutes: 1), (timer) {
//       _updateExpiryTimeDisplay(expiryTime);
//     });
//   }
  
//   void _updateExpiryTimeDisplay(DateTime expiryTime) {
//     final now = DateTime.now();
//     final difference = expiryTime.difference(now);
    
//     if (difference.isNegative) {
//       // Chat has expired
//       setState(() {
//         isChatExpired = true;
//         expiryTimeDisplay = "Expired";
//       });
//       expiryTimer?.cancel();
//       return;
//     }
    
//     // Format the remaining time
//     final hours = difference.inHours;
//     final minutes = difference.inMinutes.remainder(60);
    
//     setState(() {
//       expiryTimeDisplay = "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}";
//     });
//   }
  
//   String formatTimestamp(Timestamp timestamp) {
//     DateTime dateTime = timestamp.toDate();
    
//     // Format like "04/04 12:44 PM" as in the screenshot
//     return DateFormat('MM/dd hh:mm a').format(dateTime);
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Color(0xFFE5DDD5), // WhatsApp chat background color
//       appBar: AppBar(
//         backgroundColor: Color(0xFFEDEDED), // Light gray header background
//         elevation: 0,
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () {
//             Navigator.pop(context);
//           },
//         ),
//         titleSpacing: 0,
//         title: Row(
//           children: [
//             // Contact avatar
//             CircleAvatar(
//               backgroundColor: Color(0xFF8000FF),
//               radius: 20,
//               child: Text(
//                 widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : 'U',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//             ),
//             SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     widget.contactName,
//                     style: TextStyle(
//                       color: Colors.black,
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                   Row(
//                     children: [
//                       Container(
//                         padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                         decoration: BoxDecoration(
//                           color: Color.fromARGB(255, 232, 210, 255),
//                           borderRadius: BorderRadius.circular(10),
//                         ),
//                         child: Text(
//                           'Open',
//                           style: TextStyle(
//                             color: Color(0xFF8000FF),
//                             fontSize: 12,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ),
//                       SizedBox(width: 6),
//                       Icon(Icons.fiber_manual_record, size: 6, color: Colors.grey),
//                       SizedBox(width: 4),
//                       Text(
//                         'Bot',
//                         style: TextStyle(
//                           color: Colors.grey.shade700,
//                           fontSize: 13,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         // actions: [
//         //   IconButton(
//         //     icon: Icon(Icons.more_vert, color: Colors.black),
//         //     onPressed: () {
//         //       // Handle more options
//         //     },
//         //   ),
//         // ],
//       ),
//       body: Column(
//         children: [
//           // Chat expiry indicator
//           if (!isChatExpired)
//             Container(
//               padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
//               color: Colors.white,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.access_time, size: 18, color: Color(0xFF8000FF),),
//                   SizedBox(width: 6),
//                   Text(
//                     'Chat expires in $expiryTimeDisplay',
//                     style: TextStyle(
//                       color: Color(0xFF8000FF),
//                       fontSize: 14,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
            
//           // Messages list
//           Expanded(
//             child: isLoading
//               ? Center(child: CircularProgressIndicator(color: Color(0xFF8000FF)))
//               : messages.isEmpty
//                 ? Center(child: Text('No messages found'))
//                 : ListView.builder(
//                     reverse: true,
//                     padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
//                     itemCount: messages.length,
//                     itemBuilder: (context, index) {
//                       final message = messages[index];
                      
//                       // Check if this message is the chat expiry notice
//                       if (message.containsKey('isChatExpiry') && message['isChatExpiry'] == true) {
//                         return _buildChatExpiryNotice(message);
//                       }
                      
//                       final bool isOwner = message['owner'] ?? false;
//                       final String messageType = message['type'] ?? 'text';
//                       final String messageText = message['text'] ?? '';
//                       final Timestamp created = message['date'];
//                       final String status = message['statusString'] ?? '';
//                       final String eventType = message['eventType'];
//                       final bool isBot = eventType == 'templateMessageSent_v2';
//                       final bool hasTitle = messageText.toLowerCase().contains('reminder');
//                       final String title = hasTitle ? 'Reminder: Complete Your Self-Evolution Report' : '';
                      
//                       return _buildMessageItem(
//                         isOwner: isOwner,
//                         messageType: messageType, 
//                         messageText: messageText,
//                         timestamp: created,
//                         status: status,
//                         eventType: eventType,
//                         messageData: message,
//                         isBot: isBot,
//                         title: title,
//                       );
//                     },
//                   ),
//           ),
          
//           // Input field (disabled in this view-only implementation)
//           Container(
//             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.2),
//                   spreadRadius: 1,
//                   blurRadius: 3,
//                   offset: Offset(0, -1),
//                 ),
//               ],
//             ),
//             child: Row(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey.shade600),
//                   onPressed: () {},
//                 ),
//                 Expanded(
//                   child: TextField(
//                     enabled: false, // View only
//                     decoration: InputDecoration(
//                       hintText: 'Message',
//                       hintStyle: TextStyle(color: Colors.grey.shade400),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(24),
//                         borderSide: BorderSide.none,
//                       ),
//                       filled: true,
//                       fillColor: Colors.grey.shade100,
//                       contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 8),
//                 CircleAvatar(
//                   backgroundColor: Color(0xFF8000FF),
//                   child: Icon(Icons.mic, color: Colors.white),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildChatExpiryNotice(Map<String, dynamic> message) {
//     return Container(
//       margin: EdgeInsets.symmetric(vertical: 16, horizontal: 30),
//       padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//       decoration: BoxDecoration(
//         color: Colors.white.withOpacity(0.9),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       alignment: Alignment.center,
//       child: Text(
//         message['text'] ?? 'The chat has expired\n(after 24 hours of last received message)',
//         style: TextStyle(
//           color: Colors.grey.shade600,
//           fontSize: 13,
//         ),
//         textAlign: TextAlign.center,
//       ),
//     );
//   }
  
//   Widget _buildMessageItem({
//     required bool isOwner,
//     required String messageType,
//     required String messageText,
//     required Timestamp timestamp,
//     required String status,
//     required Map messageData,
//     String eventType = '',
//     bool isBot = false,
//     String title = '',
//   }) {
//     // Determine if message should be on the left side based on eventType
//     final bool showOnLeft = eventType == 'message';
    
//     // Determine message color based on message type and sender
//     Color bubbleColor;
//     if (status == 'FAILED' || eventType == 'templateMessageFailed') {
//       bubbleColor = Colors.red.shade100; // Red for failed messages
//     }
//     //  else if (isBot) {
//     //   bubbleColor = Color(0xFFD3D3D3); // Gray for bot/system messages
//     // } 
//     else {
//       // Match the WhatsApp style: custom purple for sent messages, white for received
//       bubbleColor = showOnLeft ? Colors.white : Color.fromARGB(255, 173, 91, 255);
//     }
    
//     // Text color
//     Color textColor = (showOnLeft) ? Colors.black : Colors.white;
    
//     // Check if this is a reply message
//     final bool isReply = messageData.containsKey('replyContextId') && messageData['replyContextId'] != null && messageData['replyContextId'].toString().isNotEmpty;
    
//     // Get the replied message text if it exists
//     String replyText = '';
//     String replySenderName = '';
//     if (isReply) {
//       replyText = messageData['replyText'] ?? 'Original message';
//       replySenderName = messageData['replySender'] ?? '';
//     }
    
//     return Align(
//       alignment: showOnLeft ? Alignment.centerLeft : Alignment.centerRight,
//       child: Container(
//         margin: EdgeInsets.only(
//           top: 4, 
//           bottom: 4, 
//           left: showOnLeft ? 12 : 60,
//           right: showOnLeft ? 60 : 12,
//         ),
//         child: Column(
//           crossAxisAlignment: showOnLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
//           children: [
//             Container(
//               decoration: BoxDecoration(
//                 color: bubbleColor,
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(8),
//                   topRight: Radius.circular(8),
//                   bottomLeft: showOnLeft ? Radius.circular(0) : Radius.circular(8),
//                   bottomRight: showOnLeft ? Radius.circular(8) : Radius.circular(0),
//                 ),
//               ),
//               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Title for special messages (like reminders)
//                   if (title.isNotEmpty)
//                     Padding(
//                       padding: EdgeInsets.only(bottom: 4),
//                       child: Text(
//                         title,
//                         style: TextStyle(
//                           fontWeight: FontWeight.bold,
//                           fontSize: 14,
//                           color: Colors.grey.shade700,
//                         ),
//                       ),
//                     ),
                  
//                   // Reply context
//                   if (isReply)
//                     Container(
//                       margin: EdgeInsets.only(bottom: 8),
//                       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                       decoration: BoxDecoration(
//                         color: Colors.grey.shade200.withOpacity(0.7),
//                         borderRadius: BorderRadius.circular(6),
//                         border: Border(
//                           left: BorderSide(
//                             color: Colors.blue.shade300,
//                             width: 4,
//                           ),
//                         ),
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           if (replySenderName.isNotEmpty)
//                             Text(
//                               replySenderName,
//                               style: TextStyle(
//                                 fontSize: 13,
//                                 fontWeight: FontWeight.bold,
//                                 color: Colors.blue.shade700,
//                               ),
//                             ),
//                           SizedBox(height: replySenderName.isNotEmpty ? 2 : 0),
//                           Text(
//                             replyText,
//                             style: TextStyle(
//                               fontSize: 13,
//                               color: Colors.grey.shade700,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ],
//                       ),
//                     ),
                  
//                   // Message content
//                   if (messageType == 'text' || messageType == 'template')
//                     Text(
//                       messageText,
//                       style: TextStyle(
//                         fontSize: 14.5,
//                         color: textColor,
//                       ),
//                     )
//                   else if (messageType == 'image')
//                     Container(
//                       padding: EdgeInsets.symmetric(vertical: 4),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           // Check if the message data contains an image URL
//                           if (messageData.containsKey('mediaUrl') && messageData['mediaUrl'] != null)
//                             ClipRRect(
//                               borderRadius: BorderRadius.circular(8),
//                               child: Image.network(
//                                 messageData['mediaUrl'],
//                                 width: double.infinity,
//                                 height: 180,
//                                 fit: BoxFit.cover,
//                                 loadingBuilder: (context, child, loadingProgress) {
//                                   if (loadingProgress == null) return child;
//                                   return Container(
//                                     width: double.infinity,
//                                     height: 180,
//                                     decoration: BoxDecoration(
//                                       color: Colors.grey.shade200,
//                                       borderRadius: BorderRadius.circular(8),
//                                     ),
//                                     child: Center(
//                                       child: CircularProgressIndicator(
//                                         value: loadingProgress.expectedTotalBytes != null
//                                             ? loadingProgress.cumulativeBytesLoaded / 
//                                                 loadingProgress.expectedTotalBytes!
//                                             : null,
//                                         color: Color(0xFF8000FF),
//                                       ),
//                                     ),
//                                   );
//                                 },
//                                 errorBuilder: (context, error, stackTrace) {
//                                   return Container(
//                                     width: double.infinity,
//                                     height: 150,
//                                     decoration: BoxDecoration(
//                                       color: Colors.grey.shade300,
//                                       borderRadius: BorderRadius.circular(8),
//                                     ),
//                                     child: Column(
//                                       mainAxisAlignment: MainAxisAlignment.center,
//                                       children: [
//                                         Icon(Icons.broken_image, size: 40, color: Colors.grey),
//                                         SizedBox(height: 8),
//                                         Text(
//                                           'Failed to load image',
//                                           style: TextStyle(color: Colors.grey.shade700),
//                                         ),
//                                       ],
//                                     ),
//                                   );
//                                 },
//                               ),
//                             )
//                           else
//                             Container(
//                               width: double.infinity,
//                               height: 150,
//                               decoration: BoxDecoration(
//                                 color: Colors.grey.shade300,
//                                 borderRadius: BorderRadius.circular(8),
//                               ),
//                               child: const Center(
//                                 child: Icon(Icons.image, size: 48, color: Colors.grey),
//                               ),
//                             ),
//                           // Caption
//                           if (messageText.isNotEmpty)
//                             Padding(
//                               padding: const EdgeInsets.only(top: 6),
//                               child: Text(
//                                 messageText,
//                                 style: TextStyle(color: textColor),
//                               ),
//                             ),
//                         ],
//                       ),
//                     )
//                   else if (messageType == 'document')
//                     Container(
//                       padding: EdgeInsets.all(4),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(Icons.insert_drive_file, size: 36, color: Colors.blue),
//                           SizedBox(width: 8),
//                           Flexible(
//                             child: Text(
//                               messageText.isNotEmpty ? messageText : 'Document',
//                               style: TextStyle(fontSize: 14, color: textColor),
//                             ),
//                           ),
//                         ],
//                       ),
//                     )
//                   else
//                     Text(
//                       'Unsupported message type: $messageType',
//                       style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: textColor),
//                     ),
                    
//                   // Timestamp and read status - align to the right bottom
//                   Padding(
//                     padding: EdgeInsets.only(top: 2),
//                     child: Align(
//                       alignment: Alignment.bottomRight,
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         mainAxisAlignment: MainAxisAlignment.end,
//                         children: [
//                           Text(
//                             formatTimestamp(timestamp),
//                             style: TextStyle(
//                               fontSize: 10,
//                               color: Colors.grey.shade600,
//                             ),
//                           ),
//                           SizedBox(width: 3),
//                           // Show WhatsApp check marks only for messages not on the left side
//                           if (!showOnLeft && !isBot) // Only show status icons for outgoing non-bot messages
//                             status == 'FAILED' 
//                                 ? Icon(
//                                     Icons.error_outline,
//                                     size: 12,
//                                     color: Colors.red,
//                                   )
//                                 : Icon(
//                                     status == 'READ' 
//                                         ? Icons.done_all 
//                                         : status == 'DELIVERED' 
//                                             ? Icons.done_all
//                                             : Icons.done,
//                                     size: 12,
//                                     color: status == 'READ' ? Colors.blue : Colors.grey.shade600,
//                                   ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
  
//   String formatPhoneNumber(String phoneNumber) {
//     // Basic formatting for phone numbers
//     if (phoneNumber.length > 10) {
//       // For numbers with country code
//       String countryCode = phoneNumber.substring(0, phoneNumber.length - 10);
//       String mainNumber = phoneNumber.substring(phoneNumber.length - 10);
      
//       if (mainNumber.length >= 10) {
//         return '+$countryCode ${mainNumber.substring(0, 3)} ${mainNumber.substring(3, 6)} ${mainNumber.substring(6)}';
//       }
//     }
    
//     // Return as is if we can't format it
//     return phoneNumber;
//   }
  
//   // Add an expiry message to the messages list
//   void addExpiryMessage() {
//     // Check if there's already an expiry message
//     bool hasExpiryMessage = messages.any((message) => message.containsKey('isChatExpiry'));
    
//     if (!hasExpiryMessage) {
//       setState(() {
//         messages.insert(0, {
//           'isChatExpiry': true,
//           'text': 'The chat has been expired\n(after 24 hours of last received message)',
//           'date': Timestamp.now(),
//         });
//       });
//     }
//   }
// }
