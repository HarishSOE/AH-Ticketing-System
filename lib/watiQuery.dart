import 'package:ahticketing/AppServices/AppService.dart';
import 'package:ahticketing/Widgets/customDateRangePicker.dart';
import 'package:ahticketing/chatDetail.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:intl/intl.dart';


class InboxScreen extends StatefulWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription? watiSubscription;
  StreamSubscription? profilelistSubscription;

  Map<String, List<dynamic>> mapConversation = {};
  Map<String, List<dynamic>> filteredConversations = {};
  List<MapEntry<String, List<dynamic>>> displayedConversations = [];
  Map<String, Map> mapProfileNumber = {};
  Map mapWatiTemplate = {};

  List<dynamic> templates = [];

  bool isLoading = true;
  bool isSearching = false;
  bool isLoadingMore = false;
  
  // Pagination
  final int pageSize = 50;
  int currentIndex = 0;
  
  // Date filtering
  DateTime startDate = DateTime.now().subtract(const Duration(days: 15));
  DateTime endDate = DateTime.now();

  String selectedTab = 'All Chats';
  
  @override
  void initState() {
    super.initState();

    profilelistSubscription = firestore.collection("profile_data").orderBy("name",descending: false).snapshots().listen((profiledoc) { 
      if(profiledoc.docs.length > 0){
        for (int i = 0; i < profiledoc.docs.length; i++) {
          Map profile = profiledoc.docs[i].data() as Map;
          var number = profile['countrycode'].toString()+profile['number'].toString();
          setState(() {
            mapProfileNumber[number.toString()] = profile;
          });
        }
      }
    });

    AppService().fetchTemplates().then((value) {
      print('TEMPLATES FETCH COUNT : ${value['templates'].length}');
      print('TEMPLATES MAPPED COUNT : ${value['mapWatiTemplate'].length}');
      templates = value['templates'] ?? [];
      mapWatiTemplate = value['mapWatiTemplate'] ?? {};
    });

    // Set up scroll controller for lazy loading
    _scrollController.addListener(_onScroll);

    fetchWatiConversations();
  }
  
  @override
  void dispose() {
    watiSubscription?.cancel();
    profilelistSubscription?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (isLoadingMore) return;

    List<MapEntry<String, List<dynamic>>> allConversations = [];
    filteredConversations.forEach((waId, messages) {
      allConversations.add(MapEntry(waId, messages));
    });
    
    // Sort conversations
    allConversations.sort((a, b) {
      Timestamp aLatestTimestamp = a.value.first['date'];
      Timestamp bLatestTimestamp = b.value.first['date'];
      return bLatestTimestamp.compareTo(aLatestTimestamp);
    });
    
    if (currentIndex >= allConversations.length) return;
    
    setState(() {
      isLoadingMore = true;
    });
    
    int endIndex = currentIndex + pageSize;
    if (endIndex > allConversations.length) {
      endIndex = allConversations.length;
    }
    
    List<MapEntry<String, List<dynamic>>> nextItems = allConversations.sublist(currentIndex, endIndex);
    
    setState(() {
      displayedConversations.addAll(nextItems);
      currentIndex = endIndex;
      isLoadingMore = false;
    });
  }
  
  void fetchWatiConversations() {
    setState(() {
      isLoading = true;
      mapConversation = {};
      filteredConversations = {};
      displayedConversations = [];
      currentIndex = 0;
    });
    
    // Convert DateTime to Timestamp for Firestore query
    Timestamp startTimestamp = Timestamp.fromDate(startDate);
    Timestamp endTimestamp = Timestamp.fromDate(endDate);
    
    print('Querying from ${startTimestamp.toDate()} to ${endTimestamp.toDate()}');
    
    // Base query with date filter
    Query watiCollection = firestore
        .collection("wati logs")
        .where("date", isGreaterThanOrEqualTo: startTimestamp)
        .where("date", isLessThanOrEqualTo: endTimestamp)
        .orderBy("date", descending: true);
    
    // Add watiName filter if not on "All Chats" tab
    if (selectedTab != 'All Chats') {
      watiCollection = watiCollection.where("watiName", isEqualTo: selectedTab);
    }
    
    watiSubscription = watiCollection.snapshots().listen((watidoc) {
      if (watidoc.docs.isNotEmpty) {
        Map<String, List<dynamic>> newMapConversation = {};
        
        for (int i = 0; i < watidoc.docs.length; i++) {
          Map watidata = watidoc.docs[i].data() as Map;
          
          if (watidata['waId'] != null) {
            String waId = watidata['waId'];
            String formattedPhone = formatPhoneNumber(watidata['waId']);
            watidata['contactName'] = mapProfileNumber[formattedPhone.replaceAll(' ','').toString()]?['name'] ?? formattedPhone.toString().replaceAll(' ','');
            if (!newMapConversation.containsKey(waId)) {
              newMapConversation[waId] = [];
            }
            
            newMapConversation[waId]!.add(watidata);
          }
        }
        
        // Sort each conversation by 'date' timestamp in descending order
        newMapConversation.forEach((key, value) {
          value.sort((a, b) {
            Timestamp aTimestamp = a['date'];
            Timestamp bTimestamp = b['date'];
            return bTimestamp.compareTo(aTimestamp);
          });
        });
        
        setState(() {
          mapConversation = newMapConversation;
          // Apply search filter if searching
          if (isSearching && _searchController.text.isNotEmpty) {
            _filterConversations(_searchController.text);
          } else {
            filteredConversations = newMapConversation;
            _resetPagination();
          }
          isLoading = false;
        });
      } else {
        setState(() {
          mapConversation = {};
          filteredConversations = {};
          displayedConversations = [];
          isLoading = false;
        });
      }
    },
     onError: (error) {
      print('Error fetching conversations: $error');
      setState(() {
        isLoading = false;
      });
    });
  }
  
  void _resetPagination() {
    List<MapEntry<String, List<dynamic>>> allConversations = [];
    filteredConversations.forEach((waId, messages) {
      allConversations.add(MapEntry(waId, messages));
    });
    
    // Sort conversations
    allConversations.sort((a, b) {
      Timestamp aLatestTimestamp = a.value.first['date'];
      Timestamp bLatestTimestamp = b.value.first['date'];
      return bLatestTimestamp.compareTo(aLatestTimestamp);
    });
    
    setState(() {
      currentIndex = 0;
      displayedConversations = [];
      
      if (allConversations.isNotEmpty) {
        int endIndex = pageSize;
        if (endIndex > allConversations.length) {
          endIndex = allConversations.length;
        }
        
        displayedConversations = allConversations.sublist(0, endIndex);
        currentIndex = endIndex;
      }
    });
  }
  
  void _filterConversations(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredConversations = mapConversation;
        isSearching = false;
        _resetPagination();
      });
      return;
    }
    
    setState(() {
      isSearching = true;
      filteredConversations = {};
      
      mapConversation.forEach((waId, messages) {
        // Get the formatted phone number
        String formattedPhone = formatPhoneNumber(waId);
        // Check if the waId itself matches
        bool waIdMatches = waId.toLowerCase().contains(query.toLowerCase());
        // Check if the formatted phone number matches
        bool phoneMatches = formattedPhone.toLowerCase().contains(query.toLowerCase());
        
        // Check if the contact name matches (if available in mapProfileNumber)
        String contactName = '';
        if (mapProfileNumber.containsKey(formattedPhone.replaceAll(' ', ''))) {
          contactName = mapProfileNumber[formattedPhone.replaceAll(' ', '')]?['name'] ?? '';
        }
        bool nameMatches = contactName.toLowerCase().contains(query.toLowerCase());
        
        // Include in filtered conversations if any match
        if (waIdMatches || phoneMatches || nameMatches) {
          filteredConversations[waId] = messages;
        }
      });
      
      // Reset pagination with new filtered results
      _resetPagination();
    });
  }
  
  void showCustomDateRangePicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomDateRangePicker(
          initialStartDate: startDate,
          initialEndDate: endDate,
          onDateRangeSelected: (DateTime newStartDate, DateTime newEndDate) {
            setState(() {
              startDate = newStartDate;
              endDate = newEndDate;
            });
            
            // Refetch with new date range
            fetchWatiConversations();
          },
        );
      },
    );
  }

  void _toggleSearch() {
    setState(() {
      isSearching = !isSearching;
      if (!isSearching) {
        _searchController.clear();
        filteredConversations = mapConversation;
        _resetPagination();
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    int totalConversations = 0;
    filteredConversations.forEach((_, __) {
      totalConversations++;
    });
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: isSearching 
            ? _buildSearchField() 
            : const Text(
                'Inbox',
                style: TextStyle(
                  color: Color(0xFF8000FF),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.grey),
            onPressed: showCustomDateRangePicker,
          ),
          IconButton(
            icon: Icon(isSearching ? Icons.close : Icons.search, color: Colors.grey),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          // Date range display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Showing: ${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                if (isSearching && _searchController.text.isNotEmpty) 
                  Expanded(
                    child: Text(
                      ' | Search: "${_searchController.text}"',
                      style: const TextStyle(
                        color: Color(0xFF8000FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          
          // Tabs (hide when searching)
          if (!isSearching || _searchController.text.isEmpty)
            Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildTab('All Chats'),
                  _buildTab('Event Wati'),
                  _buildTab('B!G Wati'),
                  _buildTab('CS Wati'),
                  _buildTab('Finance Wati'),
                ],
              ),
            ),
          
          // Search results count (when searching)
          if (isSearching && _searchController.text.isNotEmpty && !isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Found $totalConversations conversation${totalConversations != 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          
          // Chat list
          Expanded(
            child: isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8000FF))) 
                : displayedConversations.isEmpty 
                    ? _buildEmptyState()
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(top: 10),
                        itemCount: displayedConversations.length + (currentIndex < totalConversations ? 1 : 0),
                        separatorBuilder: (context, index) {
                          return index < displayedConversations.length 
                              ? const Divider(height: 1, indent: 70)
                              : SizedBox.shrink();
                        },
                        itemBuilder: (context, index) {
                          if (index == displayedConversations.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8000FF)),
                                ),
                              ),
                            );
                          }
                          
                          String waId = displayedConversations[index].key;
                          List<dynamic> messages = displayedConversations[index].value;
                          
                          // Use the first message for conversation preview
                          dynamic latestMessage = messages.first;
                          return _buildChatItem(waId, latestMessage, messages.length);
                        },
                      ),
          ),
          
          // Display pagination info
          if (!isLoading && totalConversations > pageSize && !isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text(
                'Showing ${displayedConversations.length} of $totalConversations conversations',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Color(0xFF8000FF),
        unselectedItemColor: Colors.grey,
        currentIndex: 0, // Team Inbox is selected
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.inbox),
            label: 'Wati Inbox',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts),
            label: 'Customer SUpport',
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
        hintText: 'Search by name or number...',
        hintStyle: TextStyle(color: Colors.grey.shade400),
        border: InputBorder.none,
      ),
      style: TextStyle(
        color: Color(0xFF8000FF),
        fontSize: 16,
      ),
      onChanged: (value) {
        _filterConversations(value);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.inbox_outlined, 
            size: 48, 
            color: Colors.grey.shade400
          ),
          const SizedBox(height: 16),
          Text(
            isSearching && _searchController.text.isNotEmpty
                ? 'No results found for "${_searchController.text}"'
                : selectedTab == 'All Chats' 
                    ? 'No conversations found for selected date range'
                    : 'No conversations found for $selectedTab in the selected date range',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (isSearching && _searchController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                'Try a different search term or check the spelling',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTab(String text) {
    final isSelected = selectedTab == text;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = text;
        });
        // Fetch conversations with new filter
        fetchWatiConversations();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF8000FF) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildChatItem(String waId, dynamic messageData, int messageCount) {
    // Format the phone number for display
    String formattedPhone = formatPhoneNumber(waId);
    
    // Get message details
    String text = messageData['text'] ?? 'Media message';
    bool isOwner = messageData['owner'] ?? false;
    String messageType = messageData['type'] ?? 'text';
    Timestamp createdTimestamp = messageData['date'];
    DateTime createdDate = createdTimestamp.toDate();
    String timeDisplay = _getTimeDisplay(createdDate);
    String operatorName = messageData['operatorName'] ?? '';
    String statusString = messageData['statusString'] ?? '';
    String contactName = messageData['contactName'] ?? '';
    // Determine status label
    String statusLabel = '';
    if (statusString == 'SENT') {
      statusLabel = 'Sent';
    } else if (statusString == 'DELIVERED') {
      statusLabel = 'Delivered';
    } else if (statusString == 'READ') {
      statusLabel = 'Read';
    }
    
    IconData iconShape = Icons.circle_outlined;
    if (messageType == 'image') {
      iconShape = Icons.diamond_outlined;
    } else if (messageType == 'document') {
      iconShape = Icons.square_outlined;
    }
    
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey.shade200,
            child: Icon(
              iconShape,
              color: Color(0xFF8000FF),
              size: 24,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF8000FF),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: isSearching && _searchController.text.isNotEmpty ? 
              _buildHighlightedText(
                contactName,
                _searchController.text
              ) :
              Text(
                contactName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ),
          if (operatorName.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.headset_mic, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  operatorName,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
          Text(
            timeDisplay,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  isOwner ? 'You: $text' : text,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // if (messageCount > 1)
              //   Container(
              //     margin: const EdgeInsets.only(left: 5),
              //     width: 20,
              //     height: 20,
              //     decoration: const BoxDecoration(
              //       color: Colors.red,
              //       shape: BoxShape.circle,
              //     ),
              //     child: Center(
              //       child: Text(
              //         messageCount > 9 ? '9+' : messageCount.toString(),
              //         style: const TextStyle(
              //           color: Colors.white,
              //           fontSize: 12,
              //           fontWeight: FontWeight.bold,
              //         ),
              //       ),
              //     ),
              //   ),
            ],
          ),
          if (statusLabel.isNotEmpty)
            Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(statusLabel),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusLabel == 'Open' ? Colors.white : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
                SizedBox(width: 5,),
                if(messageData['watiName'] != null && messageData['watiName'] != '' && selectedTab == 'All Chats')
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Color(0xFF8000FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    messageData['watiName'] ?? '',
                    style: TextStyle(
                      color:Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w400
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
        ],
      ),
      onTap: () {
        // Navigate to conversation detail page
        Navigator.push(context,MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            waId: waId,
            contactName: contactName,
            latestMessage: messageData,
            selectWati : selectedTab
          ),),
        );
      },
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final String lowerCaseText = text.toLowerCase();
    final String lowerCaseQuery = query.toLowerCase();
    
    if (!lowerCaseText.contains(lowerCaseQuery)) {
      return Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black,
          ),
        ));
        break;
      }
      
      // Add text before the match
      if (indexOfMatch > start) {
        spans.add(TextSpan(
          text: text.substring(start, indexOfMatch),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.black,
          ),
        ));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + query.length),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF8000FF),
          backgroundColor: Color(0xFFEADCFF),
        ),
      ));
      
      // Move start index after this match
      start = indexOfMatch + query.length;
    }
    
    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Sent':
        return Colors.grey.shade200;
      case 'Delivered':
        return Colors.blue.shade100;
      case 'Read':
        return Color(0xFF8000FF);
      case 'Open':
        return Color(0xFF8000FF);
      default:
        return Colors.transparent;
    }
  }

  String _getTimeDisplay(DateTime messageTime) {
    DateTime now = DateTime.now();
    
    if (messageTime.year == now.year && 
        messageTime.month == now.month && 
        messageTime.day == now.day) {
      return DateFormat('h:mm a').format(messageTime);
    } else if (messageTime.isAfter(now.subtract(const Duration(days: 7)))) {
      return DateFormat('E').format(messageTime); // Day of week
    } else {
      return DateFormat('MMM d').format(messageTime);
    }
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
}


// import 'package:ahticketing/AppServices/AppService.dart';
// import 'package:ahticketing/Widgets/customDateRangePicker.dart';
// import 'package:ahticketing/chatDetail.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:async';
// import 'package:intl/intl.dart';


// class InboxScreen extends StatefulWidget {
//   const InboxScreen({Key? key}) : super(key: key);

//   @override
//   State<InboxScreen> createState() => _InboxScreenState();
// }

// class _InboxScreenState extends State<InboxScreen> {

//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//   final TextEditingController _searchController = TextEditingController();

//   StreamSubscription? watiSubscription;
//   StreamSubscription? profilelistSubscription;

//   Map<String, List<dynamic>> mapConversation = {};
//   Map<String, List<dynamic>> filteredConversations = {};
//   Map<String, Map> mapProfileNumber = {};
//   Map mapWatiTemplate = {};

//   List<dynamic> templates = [];

//   bool isLoading = true;
//   bool isSearching = false;
  
//   // Date filtering
//   DateTime startDate = DateTime.now().subtract(const Duration(days: 15));
//   DateTime endDate = DateTime.now();

//   String selectedTab = 'All Chats';
  
//   @override
//   void initState() {
//     super.initState();

//     profilelistSubscription = firestore.collection("profile_data").orderBy("name",descending: false).snapshots().listen((profiledoc) { 
//       if(profiledoc.docs.length > 0){
//         for (int i = 0; i < profiledoc.docs.length; i++) {
//           Map profile = profiledoc.docs[i].data() as Map;
//           var number = profile['countrycode'].toString()+profile['number'].toString();
//           setState(() {
//             mapProfileNumber[number.toString()] = profile;
//           });
//         }
//       }
//     });

//     AppService().fetchTemplates().then((value) {
//       print('TEMPLATES FETCH COUNT : ${value['templates'].length}');
//       print('TEMPLATES MAPPED COUNT : ${value['mapWatiTemplate'].length}');
//       templates = value['templates'] ?? [];
//       mapWatiTemplate = value['mapWatiTemplate'] ?? {};
//     });

//     fetchWatiConversations();
//   }
  
//   @override
//   void dispose() {
//     watiSubscription?.cancel();
//     profilelistSubscription?.cancel();
//     _searchController.dispose();
//     super.dispose();
//   }
  
//   void fetchWatiConversations() {
//     setState(() {
//       isLoading = true;
//       mapConversation = {};
//       filteredConversations = {};
//     });
    
//     // Convert DateTime to Timestamp for Firestore query
//     Timestamp startTimestamp = Timestamp.fromDate(startDate);
//     Timestamp endTimestamp = Timestamp.fromDate(endDate);
    
//     print('Querying from ${startTimestamp.toDate()} to ${endTimestamp.toDate()}');
    
//     // Base query with date filter
//     Query watiCollection = firestore
//         .collection("wati logs")
//         .where("date", isGreaterThanOrEqualTo: startTimestamp)
//         .where("date", isLessThanOrEqualTo: endTimestamp)
//         .orderBy("date", descending: true);
    
//     // Add watiName filter if not on "All Chats" tab
//     if (selectedTab != 'All Chats') {
//       watiCollection = watiCollection.where("watiName", isEqualTo: selectedTab);
//     }
    
//     watiSubscription = watiCollection.snapshots().listen((watidoc) {
//       if (watidoc.docs.isNotEmpty) {
//         Map<String, List<dynamic>> newMapConversation = {};
        
//         for (int i = 0; i < watidoc.docs.length; i++) {
//           Map watidata = watidoc.docs[i].data() as Map;
          
//           if (watidata['waId'] != null) {
//             String waId = watidata['waId'];
//             String formattedPhone = formatPhoneNumber(watidata['waId']);
//             watidata['contactName'] = mapProfileNumber[formattedPhone.replaceAll(' ','').toString()]?['name'] ?? formattedPhone.toString().replaceAll(' ','');
//             if (!newMapConversation.containsKey(waId)) {
//               newMapConversation[waId] = [];
//             }
            
//             newMapConversation[waId]!.add(watidata);
//           }
//         }
        
//         // Sort each conversation by 'date' timestamp in descending order
//         newMapConversation.forEach((key, value) {
//           value.sort((a, b) {
//             Timestamp aTimestamp = a['date'];
//             Timestamp bTimestamp = b['date'];
//             return bTimestamp.compareTo(aTimestamp);
//           });
//         });
        
//         setState(() {
//           mapConversation = newMapConversation;
//           // Apply search filter if searching
//           if (isSearching && _searchController.text.isNotEmpty) {
//             _filterConversations(_searchController.text);
//           } else {
//             filteredConversations = newMapConversation;
//           }
//           isLoading = false;
//         });
//       } else {
//         setState(() {
//           mapConversation = {};
//           filteredConversations = {};
//           isLoading = false;
//         });
//       }
//     },
//      onError: (error) {
//       print('Error fetching conversations: $error');
//       setState(() {
//         isLoading = false;
//       });
//     });
//   }
  
//   void _filterConversations(String query) {
//     if (query.isEmpty) {
//       setState(() {
//         filteredConversations = mapConversation;
//         isSearching = false;
//       });
//       return;
//     }
    
//     setState(() {
//       isSearching = true;
//       filteredConversations = {};
      
//       mapConversation.forEach((waId, messages) {
//         // Get the formatted phone number
//         String formattedPhone = formatPhoneNumber(waId);
//         // Check if the waId itself matches
//         bool waIdMatches = waId.toLowerCase().contains(query.toLowerCase());
//         // Check if the formatted phone number matches
//         bool phoneMatches = formattedPhone.toLowerCase().contains(query.toLowerCase());
        
//         // Check if the contact name matches (if available in mapProfileNumber)
//         String contactName = '';
//         if (mapProfileNumber.containsKey(formattedPhone.replaceAll(' ', ''))) {
//           contactName = mapProfileNumber[formattedPhone.replaceAll(' ', '')]?['name'] ?? '';
//         }
//         bool nameMatches = contactName.toLowerCase().contains(query.toLowerCase());
        
//         // Include in filtered conversations if any match
//         if (waIdMatches || phoneMatches || nameMatches) {
//           filteredConversations[waId] = messages;
//         }
//       });
//     });
//   }
  
//   void showCustomDateRangePicker() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return CustomDateRangePicker(
//           initialStartDate: startDate,
//           initialEndDate: endDate,
//           onDateRangeSelected: (DateTime newStartDate, DateTime newEndDate) {
//             setState(() {
//               startDate = newStartDate;
//               endDate = newEndDate;
//             });
            
//             // Refetch with new date range
//             fetchWatiConversations();
//           },
//         );
//       },
//     );
//   }

//   void _toggleSearch() {
//     setState(() {
//       isSearching = !isSearching;
//       if (!isSearching) {
//         _searchController.clear();
//         filteredConversations = mapConversation;
//       }
//     });
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     // Convert filteredConversations to a sorted list of conversations
//     List<MapEntry<String, List<dynamic>>> conversationList = [];
    
//     filteredConversations.forEach((waId, messages) {
//       conversationList.add(MapEntry(waId, messages));
//     });
    
//     // Sort conversations by the date time of the latest message
//     conversationList.sort((a, b) {
//       Timestamp aLatestTimestamp = a.value.first['date'];
//       Timestamp bLatestTimestamp = b.value.first['date'];
//       return bLatestTimestamp.compareTo(aLatestTimestamp);
//     });
    
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         title: isSearching 
//             ? _buildSearchField() 
//             : const Text(
//                 'Inbox',
//                 style: TextStyle(
//                   color: Color(0xFF8000FF),
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.calendar_today, color: Colors.grey),
//             onPressed: showCustomDateRangePicker,
//           ),
//           IconButton(
//             icon: Icon(isSearching ? Icons.close : Icons.search, color: Colors.grey),
//             onPressed: _toggleSearch,
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Date range display
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Row(
//               children: [
//                 const Icon(Icons.date_range, size: 16, color: Colors.grey),
//                 const SizedBox(width: 8),
//                 Text(
//                   'Showing: ${DateFormat('MMM dd, yyyy').format(startDate)} - ${DateFormat('MMM dd, yyyy').format(endDate)}',
//                   style: const TextStyle(
//                     color: Colors.grey,
//                     fontSize: 12,
//                   ),
//                 ),
//                 if (isSearching && _searchController.text.isNotEmpty) 
//                   Expanded(
//                     child: Text(
//                       ' | Search: "${_searchController.text}"',
//                       style: const TextStyle(
//                         color: Color(0xFF8000FF),
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                   ),
//               ],
//             ),
//           ),
          
//           // Tabs (hide when searching)
//           if (!isSearching || _searchController.text.isEmpty)
//             Container(
//               height: 40,
//               margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
//               child: ListView(
//                 scrollDirection: Axis.horizontal,
//                 children: [
//                   _buildTab('All Chats'),
//                   _buildTab('Event Wati'),
//                   _buildTab('B!G Wati'),
//                   _buildTab('CS Wati'),
//                   _buildTab('Finance Wati'),
//                 ],
//               ),
//             ),
          
//           // Search results count (when searching)
//           if (isSearching && _searchController.text.isNotEmpty && !isLoading)
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               child: Row(
//                 children: [
//                   Text(
//                     'Found ${conversationList.length} conversation${conversationList.length != 1 ? 's' : ''}',
//                     style: const TextStyle(
//                       color: Colors.grey,
//                       fontSize: 14,
//                       fontStyle: FontStyle.italic,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
          
//           // Chat list
//           Expanded(
//             child: isLoading 
//                 ? const Center(child: CircularProgressIndicator(color: Color(0xFF8000FF))) 
//                 : conversationList.isEmpty 
//                     ? _buildEmptyState()
//                     : ListView.separated(
//                         padding: const EdgeInsets.only(top: 10),
//                         itemCount: conversationList.length,
//                         separatorBuilder: (context, index) {
//                           return const Divider(height: 1, indent: 70);
//                         },
//                         itemBuilder: (context, index) {
//                           String waId = conversationList[index].key;
//                           List<dynamic> messages = conversationList[index].value;
                          
//                           // Use the first message for conversation preview
//                           dynamic latestMessage = messages.first;
                          
//                           return _buildChatItem(waId, latestMessage, messages.length);
//                         },
//                       ),
//           ),
//         ],
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         type: BottomNavigationBarType.fixed,
//         selectedItemColor: Color(0xFF8000FF),
//         unselectedItemColor: Colors.grey,
//         currentIndex: 0, // Team Inbox is selected
//         items: const [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.inbox),
//             label: 'Wati Inbox',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.contacts),
//             label: 'Customer SUpport',
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildSearchField() {
//     return TextField(
//       controller: _searchController,
//       autofocus: true,
//       decoration: InputDecoration(
//         hintText: 'Search by name or number...',
//         hintStyle: TextStyle(color: Colors.grey.shade400),
//         border: InputBorder.none,
//       ),
//       style: TextStyle(
//         color: Color(0xFF8000FF),
//         fontSize: 16,
//       ),
//       onChanged: (value) {
//         _filterConversations(value);
//       },
//     );
//   }

//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             isSearching ? Icons.search_off : Icons.inbox_outlined, 
//             size: 48, 
//             color: Colors.grey.shade400
//           ),
//           const SizedBox(height: 16),
//           Text(
//             isSearching && _searchController.text.isNotEmpty
//                 ? 'No results found for "${_searchController.text}"'
//                 : selectedTab == 'All Chats' 
//                     ? 'No conversations found for selected date range'
//                     : 'No conversations found for $selectedTab in the selected date range',
//             style: TextStyle(
//               color: Colors.grey.shade600,
//               fontSize: 16,
//             ),
//             textAlign: TextAlign.center,
//           ),
//           if (isSearching && _searchController.text.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.only(top: 8.0),
//               child: Text(
//                 'Try a different search term or check the spelling',
//                 style: TextStyle(
//                   color: Colors.grey.shade500,
//                   fontSize: 14,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTab(String text) {
//     final isSelected = selectedTab == text;
//     return GestureDetector(
//       onTap: () {
//         setState(() {
//           selectedTab = text;
//         });
//         // Fetch conversations with new filter
//         fetchWatiConversations();
//       },
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//         margin: const EdgeInsets.only(right: 10),
//         decoration: BoxDecoration(
//           color: isSelected ? Color(0xFF8000FF) : Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(5),
//         ),
//         child: Text(
//           text,
//           style: TextStyle(
//             color: isSelected ? Colors.white : Colors.grey,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildChatItem(String waId, dynamic messageData, int messageCount) {
//     // Format the phone number for display
//     String formattedPhone = formatPhoneNumber(waId);
    
//     // Get message details
//     String text = messageData['text'] ?? 'Media message';
//     bool isOwner = messageData['owner'] ?? false;
//     String messageType = messageData['type'] ?? 'text';
//     Timestamp createdTimestamp = messageData['date'];
//     DateTime createdDate = createdTimestamp.toDate();
//     String timeDisplay = _getTimeDisplay(createdDate);
//     String operatorName = messageData['operatorName'] ?? '';
//     String statusString = messageData['statusString'] ?? '';
//     String contactName = messageData['contactName'] ?? '';
//     // Determine status label
//     String statusLabel = '';
//     if (statusString == 'SENT') {
//       statusLabel = 'Sent';
//     } else if (statusString == 'DELIVERED') {
//       statusLabel = 'Delivered';
//     } else if (statusString == 'READ') {
//       statusLabel = 'Read';
//     }
    
//     IconData iconShape = Icons.circle_outlined;
//     if (messageType == 'image') {
//       iconShape = Icons.diamond_outlined;
//     } else if (messageType == 'document') {
//       iconShape = Icons.square_outlined;
//     }
    
//     return ListTile(
//       leading: Stack(
//         children: [
//           CircleAvatar(
//             radius: 20,
//             backgroundColor: Colors.grey.shade200,
//             child: Icon(
//               iconShape,
//               color: Color(0xFF8000FF),
//               size: 24,
//             ),
//           ),
//           Positioned(
//             bottom: 0,
//             right: 0,
//             child: Container(
//               width: 12,
//               height: 12,
//               decoration: const BoxDecoration(
//                 color: Color(0xFF8000FF),
//                 shape: BoxShape.circle,
//               ),
//             ),
//           ),
//         ],
//       ),
//       title: Row(
//         children: [
//           Expanded(
//             child: isSearching && _searchController.text.isNotEmpty ? 
//               _buildHighlightedText(
//                 mapProfileNumber[formattedPhone.replaceAll(' ','').toString()]?['name'] ?? formattedPhone.toString().replaceAll(' ',''),
//                 _searchController.text
//               ) :
//               Text(
//                 contactName,
//                 style: const TextStyle(
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//               ),
//           ),
//           if (operatorName.isNotEmpty)
//             Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 const Icon(Icons.headset_mic, size: 16, color: Colors.grey),
//                 const SizedBox(width: 4),
//                 Text(
//                   operatorName,
//                   style: TextStyle(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                 ),
//               ],
//             ),
//           const SizedBox(width: 8),
//           Text(
//             timeDisplay,
//             style: const TextStyle(
//               color: Colors.grey,
//               fontSize: 13,
//             ),
//           ),
//         ],
//       ),
//       subtitle: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const SizedBox(height: 4),
//           Row(
//             children: [
//               Expanded(
//                 child: Text(
//                   isOwner ? 'You: $text' : text,
//                   style: const TextStyle(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               if (messageCount > 1)
//                 Container(
//                   margin: const EdgeInsets.only(left: 5),
//                   width: 20,
//                   height: 20,
//                   decoration: const BoxDecoration(
//                     color: Colors.red,
//                     shape: BoxShape.circle,
//                   ),
//                   child: Center(
//                     child: Text(
//                       messageCount > 9 ? '9+' : messageCount.toString(),
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 12,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//           if (statusLabel.isNotEmpty)
//             Container(
//               margin: const EdgeInsets.only(top: 5),
//               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
//               decoration: BoxDecoration(
//                 color: _getStatusColor(statusLabel),
//                 borderRadius: BorderRadius.circular(4),
//               ),
//               child: Text(
//                 statusLabel,
//                 style: TextStyle(
//                   color: statusLabel == 'Open' ? Colors.white : Colors.black54,
//                   fontSize: 12,
//                 ),
//               ),
//             ),
//           const SizedBox(height: 5),
//         ],
//       ),
//       onTap: () {
//         // Navigate to conversation detail page
//         Navigator.push(context,MaterialPageRoute(
//           builder: (context) => ChatDetailScreen(
//             waId: waId,
//             contactName: mapProfileNumber[formattedPhone.replaceAll(' ','').toString()]?['name'] ?? formattedPhone.toString().replaceAll(' ',''),
//             latestMessage: messageData,
//           ),),
//         );
//       },
//     );
//   }

//   Widget _buildHighlightedText(String text, String query) {
//     if (query.isEmpty) {
//       return Text(
//         text,
//         style: const TextStyle(
//           fontWeight: FontWeight.bold,
//           fontSize: 16,
//         ),
//         maxLines: 1,
//         overflow: TextOverflow.ellipsis,
//       );
//     }

//     final String lowerCaseText = text.toLowerCase();
//     final String lowerCaseQuery = query.toLowerCase();
    
//     if (!lowerCaseText.contains(lowerCaseQuery)) {
//       return Text(
//         text,
//         style: const TextStyle(
//           fontWeight: FontWeight.bold,
//           fontSize: 16,
//         ),
//         maxLines: 1,
//         overflow: TextOverflow.ellipsis,
//       );
//     }

//     List<TextSpan> spans = [];
//     int start = 0;
//     int indexOfMatch;
    
//     while (true) {
//       indexOfMatch = lowerCaseText.indexOf(lowerCaseQuery, start);
//       if (indexOfMatch == -1) {
//         // No more matches
//         spans.add(TextSpan(
//           text: text.substring(start),
//           style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//             color: Colors.black,
//           ),
//         ));
//         break;
//       }
      
//       // Add text before the match
//       if (indexOfMatch > start) {
//         spans.add(TextSpan(
//           text: text.substring(start, indexOfMatch),
//           style: const TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//             color: Colors.black,
//           ),
//         ));
//       }
      
//       // Add highlighted match
//       spans.add(TextSpan(
//         text: text.substring(indexOfMatch, indexOfMatch + query.length),
//         style: const TextStyle(
//           fontWeight: FontWeight.bold,
//           fontSize: 16,
//           color: Color(0xFF8000FF),
//           backgroundColor: Color(0xFFEADCFF),
//         ),
//       ));
      
//       // Move start index after this match
//       start = indexOfMatch + query.length;
//     }
    
//     return RichText(
//       text: TextSpan(children: spans),
//       maxLines: 1,
//       overflow: TextOverflow.ellipsis,
//     );
//   }

//   Color _getStatusColor(String status) {
//     switch (status) {
//       case 'Sent':
//         return Colors.grey.shade200;
//       case 'Delivered':
//         return Colors.blue.shade100;
//       case 'Read':
//         return Color(0xFF8000FF);
//       case 'Open':
//         return Color(0xFF8000FF);
//       default:
//         return Colors.transparent;
//     }
//   }

//   String _getTimeDisplay(DateTime messageTime) {
//     DateTime now = DateTime.now();
    
//     if (messageTime.year == now.year && 
//         messageTime.month == now.month && 
//         messageTime.day == now.day) {
//       return DateFormat('h:mm a').format(messageTime);
//     } else if (messageTime.isAfter(now.subtract(const Duration(days: 7)))) {
//       return DateFormat('E').format(messageTime); // Day of week
//     } else {
//       return DateFormat('MMM d').format(messageTime);
//     }
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
// }