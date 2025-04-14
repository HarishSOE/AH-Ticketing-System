import 'dart:io';

import 'package:ahticketing/AppServices/AppService.dart';
import 'package:ahticketing/AppServices/UserData.dart';
import 'package:ahticketing/Widgets/chatTile.dart';
import 'package:ahticketing/Widgets/customDateRangePicker.dart';
import 'package:ahticketing/chatDetail.dart';
import 'package:ahticketing/search.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({Key? key}) : super(key: key);

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();

  StreamSubscription? _watiSubscription;
  StreamSubscription? _profileSubscription;

  Map<String, List<dynamic>> _conversations = {};
  List<MapEntry<String, List<dynamic>>> _displayedConversations = [];
  Map<String, dynamic> mapProfileuid = {};
  Map<String, Map> _profileNumbers = {};

  bool _isLoading = true;
  bool _isLoadingMore = false;
  
  final int _pageSize = 50;
  DocumentSnapshot? _lastDocument;
  bool _hasMoreData = true;
  
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 15));
  DateTime _endDate = DateTime.now();

  String _selectedTab = 'All Chats';
  
  @override
  void initState() {
    super.initState();
    _loadProfiles();
    _scrollController.addListener(_onScroll);
    fetchConversations();
  }
  
  @override
  void dispose() {
    _watiSubscription?.cancel();
    _profileSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  _loadProfiles() {
    _profileSubscription = _firestore.collection("profile_data").orderBy("name", descending: false).snapshots().listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        Map<String, Map> profiles = {};
        Map<String, dynamic> uidMap = {};
        for (var doc in snapshot.docs) {
          Map profile = doc.data() as Map;
          if(profile['user_ref'] != null && profile['user_ref'] != ''){
            uidMap[profile['user_ref'].id] = profile;
          }
          var number = profile['countrycode'].toString() + profile['number'].toString();
          profiles[number] = profile;
        }
        if (mounted) {
          setState(() {
            mapProfileuid = uidMap;
            _profileNumbers = profiles;
          });
        }
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreItems();
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore || !_hasMoreData || _lastDocument == null) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    Timestamp startTimestamp = Timestamp.fromDate(_startDate);
    Timestamp endTimestamp = Timestamp.fromDate(_endDate.add(const Duration(days: 1)));
    
    Query nextQuery = _firestore.collection("wati logs").where("date", isGreaterThanOrEqualTo: startTimestamp).where("date", isLessThanOrEqualTo: endTimestamp).orderBy("date", descending: true).startAfterDocument(_lastDocument!).limit(_pageSize);
    
    if (_selectedTab != 'All Chats') {
      nextQuery = nextQuery.where("watiName", isEqualTo: _selectedTab);
    }
    
    nextQuery.get().then((watidoc) {
      if (watidoc.docs.isNotEmpty) {
        _lastDocument = watidoc.docs.last;
        
        Map<String, List<dynamic>> newConversations = _processWatiDocuments(watidoc.docs);
        
        if (mounted) {
          setState(() {
            newConversations.forEach((waId, messages) {
              if (_conversations.containsKey(waId)) {
                _conversations[waId]!.addAll(messages);
                _conversations[waId]!.sort((a, b) {
                  return b['date'].compareTo(a['date']);
                });
              } else {
                _conversations[waId] = messages;
              }
            });
            
            _hasMoreData = watidoc.docs.length >= _pageSize;
            _updateDisplayedConversations();
            _isLoadingMore = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _hasMoreData = false;
            _isLoadingMore = false;
          });
        }
      }
    }).catchError((error) {
      print('Error loading more items: $error');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    });
  }
  
  void fetchConversations() {
    setState(() {
      _isLoading = true;
      _conversations = {};
      _displayedConversations = [];
      _lastDocument = null;
      _hasMoreData = true;
    });
    
    Timestamp startTimestamp = Timestamp.fromDate(_startDate);
    Timestamp endTimestamp = Timestamp.fromDate(_endDate.add(const Duration(days: 1)));
    
    Query watiCollection = _firestore.collection("wati logs").where("date", isGreaterThanOrEqualTo: startTimestamp).where("date", isLessThanOrEqualTo: endTimestamp).orderBy("date", descending: true).limit(_pageSize);
    
    if (_selectedTab != 'All Chats') {
      watiCollection = watiCollection.where("watiName", isEqualTo: _selectedTab);
    }
    
    _watiSubscription?.cancel();
    
    _watiSubscription = watiCollection.snapshots().listen(
      (watidoc) {
        if (watidoc.docs.isNotEmpty) {
          _lastDocument = watidoc.docs.last;
          
          Map<String, List<dynamic>> newConversations = _processWatiDocuments(watidoc.docs);
          
          if (mounted) {
            setState(() {
              _conversations = newConversations;
              _hasMoreData = watidoc.docs.length >= _pageSize;
              _updateDisplayedConversations();
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _conversations = {};
              _displayedConversations = [];
              _isLoading = false;
              _hasMoreData = false;
            });
          }
        }
      },
      onError: (error) {
        print('Error fetching conversations: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    );
  }
  
  Map<String, List<dynamic>> _processWatiDocuments(List<QueryDocumentSnapshot> docs) {
    Map<String, List<dynamic>> conversations = {};

    for (var doc in docs) {
      Map watidata = doc.data() as Map;
      if (watidata['waId'] != null) {
        String waId = watidata['waId'];
        String formattedPhone = _formatPhoneNumber(waId);
        String cleanPhone = formattedPhone.replaceAll(' ', '');
        watidata['contactName'] = _profileNumbers[cleanPhone]?['name'] ?? formattedPhone.replaceAll(' ', '');
        if (!conversations.containsKey(waId)) {
          conversations[waId] = [];
        }
        conversations[waId]!.add(watidata);
      }
    }
    
    conversations.forEach((key, value) {
      value.sort((a, b) => b['date'].compareTo(a['date']));
    });
    
    return conversations;
  }
  
  void _updateDisplayedConversations() {
    List<MapEntry<String, List<dynamic>>> allConversations = _conversations.entries.toList();
    
    allConversations.sort((a, b) {
      Timestamp aLatestTimestamp = a.value.first['date'];
      Timestamp bLatestTimestamp = b.value.first['date'];
      return bLatestTimestamp.compareTo(aLatestTimestamp);
    });
    
    setState(() {
      _displayedConversations = allConversations;
    });
  }
  
  void _showDateRangePicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomDateRangePicker(
          initialStartDate: _startDate,
          initialEndDate: _endDate,
          onDateRangeSelected: (DateTime newStartDate, DateTime newEndDate) {
            setState(() {
              _startDate = newStartDate;
              _endDate = newEndDate;
            });
            fetchConversations();
          },
        );
      },
    );
  }

  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(
          startDate: _startDate,
          endDate: _endDate,
          selectedTab: _selectedTab,
          mapProfileNumber: _profileNumbers,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
            title: Text('Are you sure?'),
            content: Text('Do you want to exit the App'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('No'),
              ),
              TextButton(
                onPressed: () => exit(0),
                child: Text('Yes'),
              ),
            ],
          ),
        );
        return false;
      }, 
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Inbox',
            style: GoogleFonts.poppins(
              color: AppColors.purple,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today, color: Colors.grey),
              onPressed: _showDateRangePicker,
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.grey),
              onPressed: _navigateToSearch,
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
                    'Showing: ${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                    style: GoogleFonts.poppins(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Tabs
            _buildTabBar(),
            
            // Chat list
            Expanded(
              child: _isLoading ? const Center(
                child: SpinKitCircle(
                  color: AppColors.purple,
                  size: 40,
                ),
              ) : _displayedConversations.isEmpty ? _buildEmptyState() : _buildConversationList(),
            ),
            
            if (!_isLoading && !_isLoadingMore && _displayedConversations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Text(
                'Showing ${_displayedConversations.length} ${_hasMoreData ? "(more available)" : "(all loaded)"}',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        // bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildTab('All Chats'),
          _buildTab('Event Wati'),
          _buildTab('CS Wati'),
          _buildTab('BIG Wati'),
          _buildTab('Finance Wati'),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 10),
      itemCount: _displayedConversations.length + (_hasMoreData ? 1 : 0),
      separatorBuilder: (context, index) {
        return index < _displayedConversations.length 
            ? const Divider(height: 1, indent: 70)
            : const SizedBox.shrink();
      },
      itemBuilder: (context, index) {
        if (index == _displayedConversations.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Center(
              child: SpinKitCircle(
                color: AppColors.purple,
                size: 40,
              ),
            ),
          );
        }
        
        String waId = _displayedConversations[index].key;
        List<dynamic> messages = _displayedConversations[index].value;
        dynamic latestMessage = messages.first;
        int unreadMsg = _displayedConversations[index].value.where((e) => !(e['readby']??[]).contains(UserData().auth.currentUser?.uid)).length;
        return ChatItemWidget(
          waId: waId,
          latestMessage: latestMessage,
          messageCount: messages.length,
          searchQuery: '',
          selectedTab: _selectedTab,
          unreadMsg : unreadMsg,
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AppColors.purple,
      unselectedItemColor: Colors.grey,
      currentIndex: 0,
      onTap: (index) {
        // Handle navigation
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.inbox),
          label: 'Wati Inbox',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.contacts),
          label: 'Customer Support',
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined, 
            size: 48, 
            color: Colors.grey.shade400
          ),
          const SizedBox(height: 16),
          Text(
            _selectedTab == 'All Chats' 
                ? 'No conversations found for selected date range'
                : 'No conversations found for $_selectedTab in the selected date range',
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text) {
    final isSelected = _selectedTab == text;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = text;
        });
        fetchConversations();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.purple : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Sent':
        return Colors.grey.shade200;
      case 'Delivered':
        return Colors.blue.shade100;
      case 'Read':
        return Color.fromARGB(255, 0, 225, 255);
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
// import 'package:ahticketing/AppServices/AppService.dart';
// import 'package:ahticketing/Widgets/customDateRangePicker.dart';
// import 'package:ahticketing/chatDetail.dart';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_spinkit/flutter_spinkit.dart';
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
//   final ScrollController _scrollController = ScrollController();

//   StreamSubscription? watiSubscription;
//   StreamSubscription? profilelistSubscription;

//   Map<String, List<dynamic>> mapConversation = {};
//   Map<String, List<dynamic>> filteredConversations = {};
//   List<MapEntry<String, List<dynamic>>> displayedConversations = [];
//   Map<String, Map> mapProfileNumber = {};

//   bool isLoading = true;
//   bool isSearching = false;
//   bool isLoadingMore = false;
  
//   // Pagination
//   final int pageSize = 50;
//   int currentIndex = 0;
  
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

//     // Set up scroll controller for lazy loading
//     _scrollController.addListener(_onScroll);

//     fetchWatiConversations();
//   }
  
//   @override
//   void dispose() {
//     watiSubscription?.cancel();
//     profilelistSubscription?.cancel();
//     _searchController.dispose();
//     _scrollController.removeListener(_onScroll);
//     _scrollController.dispose();
//     super.dispose();
//   }

//   void _onScroll() {
//     if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
//       _loadMoreItems();
//     }
//   }

//   void _loadMoreItems() {
//     if (isLoadingMore) return;

//     List<MapEntry<String, List<dynamic>>> allConversations = [];
//     filteredConversations.forEach((waId, messages) {
//       allConversations.add(MapEntry(waId, messages));
//     });
    
//     // Sort conversations
//     allConversations.sort((a, b) {
//       Timestamp aLatestTimestamp = a.value.first['date'];
//       Timestamp bLatestTimestamp = b.value.first['date'];
//       return bLatestTimestamp.compareTo(aLatestTimestamp);
//     });
    
//     if (currentIndex >= allConversations.length) return;
    
//     setState(() {
//       isLoadingMore = true;
//     });
    
//     int endIndex = currentIndex + pageSize;
//     if (endIndex > allConversations.length) {
//       endIndex = allConversations.length;
//     }
    
//     List<MapEntry<String, List<dynamic>>> nextItems = allConversations.sublist(currentIndex, endIndex);
    
//     setState(() {
//       displayedConversations.addAll(nextItems);
//       currentIndex = endIndex;
//       isLoadingMore = false;
//     });
//   }
  
//   void fetchWatiConversations() {
//     setState(() {
//       isLoading = true;
//       mapConversation = {};
//       filteredConversations = {};
//       displayedConversations = [];
//       currentIndex = 0;
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
//             _resetPagination();
//           }
//           isLoading = false;
//         });
//       } else {
//         setState(() {
//           mapConversation = {};
//           filteredConversations = {};
//           displayedConversations = [];
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
  
//   void _resetPagination() {
//     List<MapEntry<String, List<dynamic>>> allConversations = [];
//     filteredConversations.forEach((waId, messages) {
//       allConversations.add(MapEntry(waId, messages));
//     });
    
//     // Sort conversations
//     allConversations.sort((a, b) {
//       Timestamp aLatestTimestamp = a.value.first['date'];
//       Timestamp bLatestTimestamp = b.value.first['date'];
//       return bLatestTimestamp.compareTo(aLatestTimestamp);
//     });
    
//     setState(() {
//       currentIndex = 0;
//       displayedConversations = [];
      
//       if (allConversations.isNotEmpty) {
//         int endIndex = pageSize;
//         if (endIndex > allConversations.length) {
//           endIndex = allConversations.length;
//         }
        
//         displayedConversations = allConversations.sublist(0, endIndex);
//         currentIndex = endIndex;
//       }
//     });
//   }
  
//   void _filterConversations(String query) {
//     if (query.isEmpty) {
//       setState(() {
//         filteredConversations = mapConversation;
//         isSearching = false;
//         _resetPagination();
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
      
//       // Reset pagination with new filtered results
//       _resetPagination();
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
//         _resetPagination();
//       }
//     });
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     int totalConversations = 0;
//     filteredConversations.forEach((_, __) {
//       totalConversations++;
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
//                 style: GoogleFonts.poppins(
//                   color: AppColors.purple,
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
//                   style: GoogleFonts.poppins(
//                     color: Colors.grey,
//                     fontSize: 12,
//                   ),
//                 ),
//                 if (isSearching && _searchController.text.isNotEmpty) 
//                   Expanded(
//                     child: Text(
//                       ' | Search: "${_searchController.text}"',
//                       style: GoogleFonts.poppins(
//                         color: AppColors.purple,
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
//                   _buildTab('BIG Wati'),
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
//                     'Found $totalConversations conversation${totalConversations != 1 ? 's' : ''}',
//                     style: GoogleFonts.poppins(
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
//                 ? const Center(
//                   child: SpinKitCircle(
//                   color: AppColors.purple,
//                   size: 40,
//                 ),) 
//                 : displayedConversations.isEmpty 
//                     ? _buildEmptyState()
//                     : ListView.separated(
//                         controller: _scrollController,
//                         padding: const EdgeInsets.only(top: 10),
//                         itemCount: displayedConversations.length + (currentIndex < totalConversations ? 1 : 0),
//                         separatorBuilder: (context, index) {
//                           return index < displayedConversations.length 
//                               ? const Divider(height: 1, indent: 70)
//                               : SizedBox.shrink();
//                         },
//                         itemBuilder: (context, index) {
//                           if (index == displayedConversations.length) {
//                             return Padding(
//                               padding: const EdgeInsets.symmetric(vertical: 20.0),
//                               child: Center(
//                                 child: SpinKitCircle(
//                                   color: AppColors.purple,
//                                   size: 40,
//                                 ),
//                               ),
//                             );
//                           }
                          
//                           String waId = displayedConversations[index].key;
//                           List<dynamic> messages = displayedConversations[index].value;
                          
//                           // Use the first message for conversation preview
//                           dynamic latestMessage = messages.first;
//                           return _buildChatItem(waId, latestMessage, messages.length);
//                         },
//                       ),
//           ),
          
//           // Display pagination info
//           if (!isLoading && totalConversations > pageSize && !isSearching)
//             Padding(
//               padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
//               child: Text(
//                 'Showing ${displayedConversations.length} of $totalConversations conversations',
//                 style: GoogleFonts.poppins(
//                   color: Colors.grey.shade600,
//                   fontSize: 12,
//                 ),
//               ),
//             ),
//         ],
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         type: BottomNavigationBarType.fixed,
//         selectedItemColor: AppColors.purple,
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
//         hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
//         border: InputBorder.none,
//       ),
//       style: GoogleFonts.poppins(
//         color: AppColors.purple,
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
//             style: GoogleFonts.poppins(
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
//                 style: GoogleFonts.poppins(
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
//           color: isSelected ? AppColors.purple : Colors.grey.shade200,
//           borderRadius: BorderRadius.circular(5),
//         ),
//         child: Text(
//           text,
//           style: GoogleFonts.poppins(
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
//               color: AppColors.purple,
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
//                 color: AppColors.purple,
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
//                 contactName,
//                 _searchController.text
//               ) :
//               Text(
//                 contactName,
//                 style: GoogleFonts.poppins(
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
//                   style: GoogleFonts.poppins(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                 ),
//               ],
//             ),
//           const SizedBox(width: 8),
//           Text(
//             timeDisplay,
//             style: GoogleFonts.poppins(
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
//                   style: GoogleFonts.poppins(
//                     color: Colors.grey,
//                     fontSize: 14,
//                   ),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),
//               // if (messageCount > 1)
//               //   Container(
//               //     margin: const EdgeInsets.only(left: 5),
//               //     width: 20,
//               //     height: 20,
//               //     decoration: const BoxDecoration(
//               //       color: Colors.red,
//               //       shape: BoxShape.circle,
//               //     ),
//               //     child: Center(
//               //       child: Text(
//               //         messageCount > 9 ? '9+' : messageCount.toString(),
//               //         style: GoogleFonts.poppins(
//               //           color: Colors.white,
//               //           fontSize: 12,
//               //           fontWeight: FontWeight.bold,
//               //         ),
//               //       ),
//               //     ),
//               //   ),
//             ],
//           ),
//           if (statusLabel.isNotEmpty)
//             Row(
//               children: [
//                 Container(
//                   margin: const EdgeInsets.only(top: 5),
//                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: _getStatusColor(statusLabel),
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Text(
//                     statusLabel,
//                     style: GoogleFonts.poppins(
//                       color: statusLabel == 'Open' ? Colors.white : Colors.black54,
//                       fontSize: 12,
//                     ),
//                   ),
//                 ),
//                 SizedBox(width: 5,),
//                 if(messageData['watiName'] != null && messageData['watiName'] != '' && selectedTab == 'All Chats')
//                 Container(
//                   margin: const EdgeInsets.only(top: 5),
//                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
//                   decoration: BoxDecoration(
//                     color: AppColors.purple,
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Text(
//                     messageData['watiName'] ?? '',
//                     style: GoogleFonts.poppins(
//                       color:Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.w400
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 5),
//         ],
//       ),
//       onTap: () {
//         // Navigate to conversation detail page
//         Navigator.push(context,MaterialPageRoute(
//           builder: (context) => ChatDetailScreen(
//             waId: waId,
//             contactName: contactName,
//             latestMessage: messageData,
//             selectWati : selectedTab
//           ),),
//         );
//       },
//     );
//   }

//   Widget _buildHighlightedText(String text, String query) {
//     if (query.isEmpty) {
//       return Text(
//         text,
//         style: GoogleFonts.poppins(
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
//         style: GoogleFonts.poppins(
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
//           style: GoogleFonts.poppins(
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
//           style: GoogleFonts.poppins(
//             fontWeight: FontWeight.bold,
//             fontSize: 16,
//             color: Colors.black,
//           ),
//         ));
//       }
      
//       // Add highlighted match
//       spans.add(TextSpan(
//         text: text.substring(indexOfMatch, indexOfMatch + query.length),
//         style: GoogleFonts.poppins(
//           fontWeight: FontWeight.bold,
//           fontSize: 16,
//           color: AppColors.purple,
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
//         return AppColors.purple;
//       case 'Open':
//         return AppColors.purple;
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