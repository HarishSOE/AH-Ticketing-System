import 'package:ahticketing/AppServices/AppService.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:ahticketing/chatDetail.dart';

class ChatItemWidget extends StatelessWidget {
  final String waId;
  final dynamic latestMessage;
  final int messageCount;
  final String searchQuery;
  final String selectedTab;
  final int unreadMsg;
  
  const ChatItemWidget({
    Key? key,
    required this.waId,
    required this.latestMessage,
    required this.messageCount,
    required this.searchQuery,
    required this.selectedTab,
    required this.unreadMsg,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get message details
    String text = latestMessage['text'] ?? 'Media message';
    bool isOwner = latestMessage['owner'] ?? false;
    String messageType = latestMessage['type'] ?? 'text';
    Timestamp createdTimestamp = latestMessage['date'];
    DateTime createdDate = createdTimestamp.toDate();
    String timeDisplay = _getTimeDisplay(createdDate);
    String operatorName = latestMessage['operatorName'] ?? '';
    String contactName = latestMessage['contactName'] ?? '';
    
    // Determine status label
    String statusLabel = '';

    if(latestMessage['eventType'] == 'message' && isOlderThan24Hours(latestMessage['date'])){
      statusLabel = "EXPIRED";
    }else if (latestMessage['eventType'] == 'message'){
      statusLabel = "RECIEVED";
    }else if (latestMessage['statusString'] == 'SENT' || latestMessage['statusString'] == 'SENDING'){
      statusLabel = "SENT";
    }else if (latestMessage['type'] == 'read'){
      statusLabel = "READ";
    }else if (latestMessage['statusString'] == 'Delivered'){
      statusLabel = "Delivered";
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
            child : CircleAvatar(
              backgroundColor: AppColors.purple,
              radius: 20,
              child: Text(
                contactName.isNotEmpty ? contactName[0].toUpperCase() : 'U',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Positioned(
          //   bottom: 0,
          //   right: 0,
          //   child: Container(
          //     width: 8,
          //     height: 8,
          //     child: Icon(
          //       iconShape,
          //       color: Colors.green,
          //       size: 18
          //     ),
          //   )
          //   // Container(
          //   //   width: 8,
          //   //   height: 8,
          //   //   decoration: const BoxDecoration(
          //   //     color: AppColors.purple,
          //   //     shape: BoxShape.circle,
          //   //   ),
          //   // ),
          // ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: _buildHighlightedText(
              contactName,
              searchQuery
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
              fontSize: 12,
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
                  searchQuery,
                  isSubtitle: true
                ),
              ),
              if (unreadMsg > 0)
              Container(
                margin: const EdgeInsets.only(left: 5),
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 226, 78, 68),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    unreadMsg > 9 ? '9+' : unreadMsg.toString(),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              if(latestMessage['watiName'] != null && latestMessage['watiName'] != '' && selectedTab == 'All Chats')
              Container(
                margin: const EdgeInsets.only(top: 5,right:5),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
                child: Text(
                  latestMessage['watiName'] ?? '',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w400
                  ),
                ),
              ),
              if (statusLabel.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 5,right: 5),
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
            ],
          ),
          const SizedBox(height: 5),
          // Text(unreadMsg.toString()),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailScreen(
              waId: waId,
              contactName: contactName,
              latestMessage: latestMessage,
              selectWati: selectedTab
            ),
          ),
        );
      },
    );
  }

  bool isOlderThan24Hours(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    Duration difference = DateTime.now().difference(dateTime);
    return difference.inHours >= 24;
  }

  Widget _buildHighlightedText(String text, String query, {bool isSubtitle = false}) {
    if (query.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.poppins(
          fontWeight: isSubtitle ? FontWeight.normal : FontWeight.bold,
          fontSize: isSubtitle ? 12 : 14,
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
          fontSize: isSubtitle ? 13 : 14,
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
            fontSize: isSubtitle ? 13 : 14,
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
            fontSize: isSubtitle ? 13 : 14,
            color: isSubtitle ? Colors.grey : Colors.black,
          ),
        ));
      }
      
      // Add highlighted match
      spans.add(TextSpan(
        text: text.substring(indexOfMatch, indexOfMatch + query.length),
        style: GoogleFonts.poppins(
          fontWeight: isSubtitle ? FontWeight.normal : FontWeight.bold,
          fontSize: isSubtitle ? 13 : 14,
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
      case 'RECIEVED' :
        return Colors.greenAccent;
      case 'SENT':
        return Color.fromARGB(255, 241, 241, 241);
      case 'Delivered':
        return Colors.blue.shade100;
      case 'READ':
        return AppColors.purple;
      case 'Open':
        return AppColors.purple;
      case 'EXPIRED':
        return Colors.red.shade300;
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
}