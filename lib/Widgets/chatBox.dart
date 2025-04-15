import 'package:ahticketing/AppServices/AppService.dart';
import 'package:ahticketing/Widgets/audiplayer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

class chatBox extends StatelessWidget {
  final bool isOwner;
  final String messageType;
  final String messageText;
  final Timestamp timestamp;
  final String status;
  final Map messageData;
  final String eventType;
  final bool isBot;
  final String title;
  final String? highlightText;
  final Map? mapProfileUid;

  const chatBox({
    Key? key,
    required this.isOwner,
    required this.messageType,
    required this.messageText,
    required this.timestamp,
    required this.status,
    required this.messageData,
    this.eventType = '',
    this.isBot = false,
    this.title = '',
    this.highlightText,
    this.mapProfileUid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool showOnLeft = eventType == 'message';
    
    Color bubbleColor;
    if (status == 'FAILED' || eventType == 'templateMessageFailed') {
      bubbleColor = Colors.red.shade100; // Red for failed messages
    } else {
      bubbleColor = showOnLeft ? Colors.white : Color.fromARGB(255, 178, 238, 181);
    }
    
    Color textColor = showOnLeft ? Color.fromARGB(255, 100, 100, 100) : AppColors.primaryText;
    Color linkColor = Color.fromARGB(255, 14, 27, 214); // Link color
    
    final bool isReply = messageData.containsKey('replyContextId') && messageData['replyContextId'] != null && messageData['replyContextId'].toString().isNotEmpty;
    
    String replyText = '';
    String replySenderName = '';
    if (isReply) {
      replyText = messageData['text'] ?? 'Original message';
      replySenderName = messageData['replySender'] ?? '';
    }
    
    final bool hasTeamReply = messageData.containsKey('teamreplay') && messageData['teamreplay'] != null && messageData['teamreplay'] is List && (messageData['teamreplay'] as List).isNotEmpty;
    
    TextStyle _textstyle = GoogleFonts.nunito(
      fontWeight: FontWeight.bold,
      color: AppColors.purple,
      fontSize:12
    );

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
                        style: _textstyle
                      ),
                    ),
                  // Team reply section
                  if (hasTeamReply)
                    _buildTeamReplySection(),
                  
                  // Reply context
                  if (isReply)
                    _buildReplySection(replySenderName, replyText),
                  
                  // Message content with highlighting if needed
                  if (messageType == 'text' || messageType == 'template' || messageType == 'interactive' || messageType == 'button')
                    _buildTextContent(messageText, textColor, linkColor)
                  else if (messageType == 'image')
                    _buildImageContent(messageText, textColor, linkColor)
                  else if (messageType == 'document')
                    _buildDocumentContent(messageText, textColor, linkColor)
                  else if(messageType == 'audio')
                    _buildAudioContent(messageData['data'], textColor, linkColor)
                  else
                    Text(
                      'Unsupported message type: $messageType',
                      style: GoogleFonts.poppins(fontSize: 14, fontStyle: FontStyle.italic, color: textColor),
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
                          Text(
                            _formatTimestamp(timestamp),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          SizedBox(width: 3),
                          // Show check marks only for outgoing non-bot messages
                          if (!showOnLeft && !isBot) 
                            _buildStatusIndicator(status),
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

  Widget _buildTeamReplySection() {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: const Color.fromARGB(255, 99, 154, 255),
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var reply in messageData['teamreplay'] as List)
            if (reply is Map && reply.containsKey('taggedby') && reply.containsKey('taggedmsg'))
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        mapProfileUid?[reply['taggedby']]['name'] ?? 'Unknown',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 99, 154, 255),
                          fontSize:12
                        ),
                      ),
                      if (reply.containsKey('taggedtime') && reply['taggedtime'] != null)
                        Text(
                          ' · ${_formatTeamReplyTime(reply['taggedtime'])}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 2),
                  // Linkify the team reply messages
                  Linkify(
                    text: reply['taggedmsg'] ?? '',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize:12
                    ),
                    linkStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    onOpen: (link) => _launchURL(link.url),
                  ),
                  if (reply != (messageData['teamreplay'] as List).last)
                    Divider(height: 12, thickness: 0.5, color: Colors.grey.shade300),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildReplySection(String replySenderName, String replyText) {
    return Container(
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
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
          SizedBox(height: replySenderName.isNotEmpty ? 2 : 0),
          // Linkify the reply text too
          Linkify(
            text: replyText,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
            linkStyle: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            onOpen: (link) => _launchURL(link.url),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent(String text, Color textColor, Color linkColor) {
    return highlightText != null && text.toLowerCase().contains(
      highlightText!.toLowerCase()
    ) ? _buildHighlightedTextWithLinks(text, highlightText!, textColor, linkColor) : Linkify(
      text: text,
      style: GoogleFonts.poppins(
        color: textColor,
        fontSize:12
      ),
      linkStyle: GoogleFonts.poppins(
        fontSize: 14.5,
        color: linkColor,
        decoration: TextDecoration.underline,
      ),
      onOpen: (link) => _launchURL(link.url),
    );
  }

  Widget _buildImageContent(String caption, Color textColor, Color linkColor) {
    return Container(
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
                        color: AppColors.purple,
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
                          style: GoogleFonts.poppins(color: Colors.grey.shade700),
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
          if (caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: highlightText != null && caption.toLowerCase().contains(highlightText!.toLowerCase())
                ? _buildHighlightedTextWithLinks(caption, highlightText!, textColor, linkColor)
                : Linkify(
                    text: caption,
                    style: GoogleFonts.poppins(color: textColor),
                    linkStyle: GoogleFonts.poppins(
                      color: linkColor,
                      decoration: TextDecoration.underline,
                    ),
                    onOpen: (link) => _launchURL(link.url),
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentContent(String documentName, Color textColor, Color linkColor) {
    return Container(
      padding: EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, size: 36, color: Colors.blue),
          SizedBox(width: 8),
          Flexible(
            child: highlightText != null && documentName.toLowerCase().contains(highlightText!.toLowerCase())
              ? _buildHighlightedTextWithLinks(documentName, highlightText!, textColor, linkColor)
              : Linkify(
                  text: documentName.isNotEmpty ? documentName : 'Document',
                  style: GoogleFonts.poppins(fontSize: 14, color: textColor),
                  linkStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: linkColor,
                    decoration: TextDecoration.underline,
                  ),
                  onOpen: (link) => _launchURL(link.url),
                ),
          ),
        ],
      ),
    );
  }

  _buildAudioContent(String mediaUrl, Color textColor, Color linkColor){
    return AudioMessageWidget(
      mediaUrl: mediaUrl,
      textColor: textColor,
      linkColor: linkColor,
    );
  }

  Widget _buildStatusIndicator(String status) {
    if (status == 'FAILED') {
      return Icon(
        Icons.error_outline,
        size: 12,
        color: Colors.red,
      );
    } else {
      return Icon(
        status == 'READ' 
            ? Icons.done_all 
            : status == 'DELIVERED' 
                ? Icons.done_all
                : Icons.done,
        size: 12,
        color: status == 'READ' ? Colors.blue : Colors.grey.shade600,
      );
    }
  }

  // Function to launch URLs
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  // Helper function to format message timestamp
  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();
    
    if (dateTime.day == now.day && 
        dateTime.month == now.month && 
        dateTime.year == now.year) {
      // Same day, show time
      return DateFormat('h:mm a').format(dateTime);
    } else if (dateTime.isAfter(now.subtract(Duration(days: 7)))) {
      // Within the last week, show day name
      return DateFormat('E, h:mm a').format(dateTime);
    } else {
      // Older than a week, show date
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  // Helper function to format team reply timestamp
  String _formatTeamReplyTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      DateTime dateTime = timestamp.toDate();
      return DateFormat('MMM d, h:mm a').format(dateTime);
    } else if (timestamp is String) {
      // Try to parse the timestamp string
      try {
        DateTime dateTime = DateTime.parse(timestamp);
        return DateFormat('MMM d, h:mm a').format(dateTime);
      } catch (e) {
        return timestamp;
      }
    }
    return '';
  }

  // Custom widget to handle both highlighting and links
  Widget _buildHighlightedTextWithLinks(String text, String highlightText, Color textColor, Color linkColor) {
    // First, find and collect all URL positions in the text
    final RegExp urlRegExp = RegExp(
      r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9]+\.[^\s]{2,}|www\.[a-zA-Z0-9]+\.[^\s]{2,})',
      caseSensitive: false,
    );
    
    final Iterable<RegExpMatch> urlMatches = urlRegExp.allMatches(text);
    List<({int start, int end, String url})> urlPositions = [];
    
    for (final match in urlMatches) {
      urlPositions.add((
        start: match.start, 
        end: match.end, 
        url: match.group(0) ?? '',
      ));
    }
    
    // Next, find highlight positions
    final String lowerCaseText = text.toLowerCase();
    final String lowerCaseHighlight = highlightText.toLowerCase();
    
    // Find all occurrences of the highlight string
    List<int> highlightPositions = [];
    int startPosition = 0;
    
    while (true) {
      final int position = lowerCaseText.indexOf(lowerCaseHighlight, startPosition);
      if (position == -1) break;
      highlightPositions.add(position);
      startPosition = position + lowerCaseHighlight.length;
    }
    
    // If no highlights or URLs, just return regular text
    if (highlightPositions.isEmpty && urlPositions.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.poppins(fontSize: 14.5, color: textColor),
      );
    }
    
    // Now build spans with both highlights and URLs
    List<InlineSpan> spans = [];
    int currentPosition = 0;
    
    // Process the text character by character, checking if each position needs special styling
    for (int i = 0; i < text.length;) {
      // Check if this position is part of a URL
      final urlEntry = urlPositions.where((u) => i >= u.start && i < u.end).toList();
      bool isPartOfUrl = urlEntry.isNotEmpty;
      
      // Check if this position is part of a highlight
      bool isPartOfHighlight = highlightPositions.any(
        (pos) => i >= pos && i < pos + lowerCaseHighlight.length
      );
      
      if (isPartOfUrl) {
        // This is a URL - create a clickable span for the entire URL
        final entry = urlEntry.first;
        
        spans.add(
          TextSpan(
            text: text.substring(entry.start, entry.end),
            style: GoogleFonts.poppins(
              color: linkColor,
              decoration: TextDecoration.underline,
              fontSize: 14.5,
              backgroundColor: isPartOfHighlight ? Color(0xFFEADCFF) : null,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _launchURL(entry.url),
          )
        );
        
        // Jump past the URL
        i = entry.end;
        currentPosition = i;
        continue;
      } else if (isPartOfHighlight) {
        // Find the end of this highlight segment
        int highlightPos = highlightPositions.firstWhere(
          (pos) => i >= pos && i < pos + lowerCaseHighlight.length
        );
        int endOfHighlight = highlightPos + lowerCaseHighlight.length;
        
        // Check if there's a URL inside this highlight
        bool highlightContainsUrl = urlPositions.any(
          (u) => u.start < endOfHighlight && u.start >= i
        );
        
        if (highlightContainsUrl) {
          // Handle this character by character to work with URLs too
          spans.add(
            TextSpan(
              text: text[i],
              style: GoogleFonts.poppins(
                backgroundColor: Color(0xFFEADCFF),
                color: textColor,
                fontSize: 14.5,
              ),
            )
          );
          i++;
          currentPosition = i;
        } else {
          // Add the whole highlight at once
          spans.add(
            TextSpan(
              text: text.substring(i, endOfHighlight),
              style: GoogleFonts.poppins(
                backgroundColor: Color(0xFFEADCFF),
                color: textColor,
                fontSize: 14.5,
              ),
            )
          );
          i = endOfHighlight;
          currentPosition = i;
        }
      } else {
        // Regular text - check for next special segment
        int nextSpecialPos = text.length;
        
        // Find the next URL
        for (final urlPos in urlPositions) {
          if (urlPos.start > i && urlPos.start < nextSpecialPos) {
            nextSpecialPos = urlPos.start;
          }
        }
        
        // Find the next highlight
        for (final highlightPos in highlightPositions) {
          if (highlightPos > i && highlightPos < nextSpecialPos) {
            nextSpecialPos = highlightPos;
          }
        }
        
        // Add text up to the next special position
        spans.add(
          TextSpan(
            text: text.substring(i, nextSpecialPos),
            style: GoogleFonts.poppins(color: textColor, fontSize: 14.5),
          )
        );
        
        i = nextSpecialPos;
        currentPosition = i;
      }
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }
}