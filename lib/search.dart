import 'package:ah_ticketing_prod/AppServices/AppService.dart';
import 'package:ah_ticketing_prod/AppServices/UserData.dart';
import 'package:ah_ticketing_prod/Widgets/chatTile.dart';
import 'package:ah_ticketing_prod/chatDetail.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class SearchScreen extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final String selectedTab;
  final Map<String, Map> mapProfileNumber;

  const SearchScreen({
    Key? key,
    required this.startDate,
    required this.endDate,
    required this.selectedTab,
    required this.mapProfileNumber,
  }) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  StreamSubscription? _searchSubscription;

  List<MapEntry<String, List<dynamic>>> _searchResults = [];
  
  bool _isLoading = false;
  bool _hasSearched = false;
  
  @override
  void initState() {
    super.initState();
    
    // Set focus to search field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }
  
  @override
  void dispose() {
    _searchSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;
    
    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _searchResults = [];
    });
    
    // Find profiles that match the search query
    List<String> matchingPhoneNumbers = [];
    
    widget.mapProfileNumber.forEach((phoneNumber, profile) {
      String name = profile['name']?.toString() ?? '';
      if (name.toLowerCase().contains(query.toLowerCase()) || 
          phoneNumber.toLowerCase().contains(query.toLowerCase())) {
        matchingPhoneNumbers.add(phoneNumber);
      }
    });
    
    // Convert DateTime to Timestamp for Firestore query
    Timestamp startTimestamp = Timestamp.fromDate(widget.startDate);
    Timestamp endTimestamp = Timestamp.fromDate(widget.endDate.add(const Duration(days: 1)));
    
    // Create base query with date filters
    Query searchQuery = _firestore
        .collection("wati logs")
        .where("date", isGreaterThanOrEqualTo: startTimestamp)
        .where("date", isLessThanOrEqualTo: endTimestamp);
    
    // Add watiName filter if not on "All Chats" tab
    if (widget.selectedTab != 'All Chats') {
      searchQuery = searchQuery.where("watiName", isEqualTo: widget.selectedTab);
    }
    
    // Order by date for consistent results
    searchQuery = searchQuery.orderBy("date", descending: true);
    
    // Cancel any previous subscription
    _searchSubscription?.cancel();
    
    // Execute the search query
    _searchSubscription = searchQuery.snapshots().listen(
      (snapshot) {
        Map<String, List<dynamic>> conversations = {};
        
        if (snapshot.docs.isNotEmpty) {
          for (var doc in snapshot.docs) {
            Map watidata = doc.data() as Map;
            
            if (watidata['waId'] != null) {
              String waId = watidata['waId'];
              String formattedPhone = _formatPhoneNumber(waId);
              String cleanPhone = formattedPhone.replaceAll(' ', '');
              
              // Check if this message matches any search criteria
              bool waIdMatches = waId.toLowerCase().contains(query.toLowerCase());
              bool phoneMatches = formattedPhone.toLowerCase().contains(query.toLowerCase());
              
              String contactName = '';
              if (widget.mapProfileNumber.containsKey(cleanPhone)) {
                contactName = widget.mapProfileNumber[cleanPhone]?['name'] ?? '';
              }
              bool nameMatches = contactName.toLowerCase().contains(query.toLowerCase());
              
              String messageText = watidata['text']?.toString() ?? '';
              bool textMatches = messageText.toLowerCase().contains(query.toLowerCase());
              
              bool profileMatches = matchingPhoneNumbers.contains(cleanPhone);
              
              // Include in search results if any match
              if (waIdMatches || phoneMatches || nameMatches || textMatches || profileMatches) {
                watidata['contactName'] = widget.mapProfileNumber[cleanPhone]?['name'] ?? formattedPhone.replaceAll(' ', '');
                
                if (!conversations.containsKey(waId)) {
                  conversations[waId] = [];
                }
                
                conversations[waId]!.add(watidata);
              }
            }
          }
          
          // Sort each conversation by date
          conversations.forEach((key, value) {
            value.sort((a, b) => b['date'].compareTo(a['date']));
          });
          
          // Convert to list for display
          List<MapEntry<String, List<dynamic>>> results = conversations.entries.toList();
          
          // Sort conversations by latest message date
          results.sort((a, b) {
            Timestamp aLatestTimestamp = a.value.first['date'];
            Timestamp bLatestTimestamp = b.value.first['date'];
            return bLatestTimestamp.compareTo(aLatestTimestamp);
          });
          
          if (mounted) {
            setState(() {
              _searchResults = results;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _searchResults = [];
              _isLoading = false;
            });
          }
        }
      },
      onError: (error) {
        print('Error during search: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: _buildSearchField(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.grey),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Date and filter info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.date_range, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Searching: ${DateFormat('MMM dd, yyyy').format(widget.startDate)} - ${DateFormat('MMM dd, yyyy').format(widget.endDate)}',
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                if (widget.selectedTab != 'All Chats')
                  Text(
                    ' | Tab: ${widget.selectedTab}',
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          
          // Search results info
          if (_hasSearched && !_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _searchResults.isEmpty ? Icons.info_outline : Icons.search,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _searchResults.isEmpty
                          ? 'No results found for "${_searchController.text}"'
                          : 'Found ${_searchResults.length} conversation${_searchResults.length != 1 ? 's' : ''} for "${_searchController.text}"',
                      style: GoogleFonts.poppins(
                        color: _searchResults.isEmpty ? Colors.grey : AppColors.purple,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          // Results list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: SpinKitCircle(
                      color: AppColors.purple,
                      size: 40,
                    ),
                  )
                : _hasSearched && _searchResults.isEmpty
                    ? _buildEmptyState()
                    : _hasSearched
                        ? _buildSearchResultsList()
                        : _buildInitialSearchState(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: 'Search by name, number or text...',
        hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
        border: InputBorder.none,
      ),
      style: GoogleFonts.poppins(
        color: AppColors.purple,
        fontSize: 16,
      ),
      textInputAction: TextInputAction.search,
      onSubmitted: (value) {
        if (value.isNotEmpty) {
          _performSearch(_searchController.text);
        }
      },
    );
  }
  
  Widget _buildSearchResultsList() {
    return ListView.separated(
      padding: const EdgeInsets.only(top: 10),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
      itemBuilder: (context, index) {
        String waId = _searchResults[index].key;
        List<dynamic> messages = _searchResults[index].value;
        
        // Use the first message for conversation preview
        dynamic latestMessage = messages.first;
        int unreadMsg = messages.where((e) => !e['readby'].contains(UserData().auth.currentUser?.uid)).length;

        return ChatItemWidget(
          waId: waId,
          latestMessage: latestMessage,
          messageCount: messages.length,
          searchQuery: _searchController.text,
          selectedTab: widget.selectedTab,
          unreadMsg : unreadMsg,
        );
      },
    );
  }

  bool isOlderThan24Hours(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    Duration difference = DateTime.now().difference(dateTime);
    return difference.inHours >= 24;
  }

  Widget _buildInitialSearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Enter name, number or message text to search',
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Press search or Enter key to begin',
            style: GoogleFonts.poppins(
              color: Colors.grey.shade500,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No results found for "${_searchController.text}"',
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Try a different search term or check the spelling',
              style: GoogleFonts.poppins(
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

  Widget _buildChatItem(String waId, dynamic messageData, int messageCount) {
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
              color: AppColors.purple,
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
                color: AppColors.purple,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: _buildHighlightedText(
              contactName,
              _searchController.text
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
                  style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          const SizedBox(width: 8),
          Text(
            timeDisplay,
            style: GoogleFonts.poppins(
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
                child: _buildHighlightedText(
                  isOwner ? 'You: $text' : text,
                  _searchController.text,
                  isSubtitle: true
                ),
              ),
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
                    style: GoogleFonts.poppins(
                      color: statusLabel == 'Open' ? Colors.white : Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                if(messageData['watiName'] != null && messageData['watiName'] != '')
                Container(
                  margin: const EdgeInsets.only(top: 5),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: const BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                  ),
                  child: Text(
                    messageData['watiName'] ?? '',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
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
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              waId: waId,
              contactName: contactName,
              latestMessage: messageData,
              selectWati: widget.selectedTab
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightedText(String text, String query, {bool isSubtitle = false}) {
    if (query.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.poppins(
          fontWeight: isSubtitle ? FontWeight.normal : FontWeight.bold,
          fontSize: isSubtitle ? 14 : 16,
          color: isSubtitle ? Colors.grey : Colors.black,
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
        style: GoogleFonts.poppins(
          fontWeight: isSubtitle ? FontWeight.normal : FontWeight.bold,
          fontSize: isSubtitle ? 14 : 16,
          color: isSubtitle ? Colors.grey : Colors.black,
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
          style: GoogleFonts.poppins(
            fontWeight: isSubtitle ? FontWeight.normal : FontWeight.bold,
            fontSize: isSubtitle ? 14 : 16,
            color: isSubtitle ? Colors.grey : Colors.black,
          ),
        ));
        break;
      }
      
      // Add text before the match
      if (indexOfMatch > start) {
        spans.add(TextSpan(
          text: text.substring(start, indexOfMatch),
          style: GoogleFonts.poppins(
            fontWeight: isSubtitle ? FontWeight.normal : FontWeight.bold,
            fontSize: isSubtitle ? 14 : 16,
            color: isSubtitle ? Colors.grey : Colors.black,
          ),
        ));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + query.length),
        style: GoogleFonts.poppins(
          fontWeight: isSubtitle ? FontWeight.normal : FontWeight.bold,
          fontSize: isSubtitle ? 14 : 16,
          color: AppColors.purple,
          backgroundColor: const Color(0xFFEADCFF),
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
        return AppColors.purple;
      case 'Open':
        return AppColors.purple;
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
  
  String _formatPhoneNumber(String phoneNumber) {
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