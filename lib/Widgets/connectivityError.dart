import 'package:ah_ticketing_prod/AppServices/connectivityService.dart';
import 'package:flutter/material.dart';

class ConnectivityErrorDialog extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onContinueOffline;

  const ConnectivityErrorDialog({
    Key? key,
    required this.onRetry,
    required this.onContinueOffline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.signal_wifi_off, color: Colors.red),
          SizedBox(width: 12),
          Text('Connection Issue'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your device does not have a healthy internet connection at the moment.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'You can continue using the app in offline mode with limited functionality, or try reconnecting.',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onContinueOffline,
          child: Text('CONTINUE OFFLINE'),
        ),
        ElevatedButton(
          onPressed: onRetry,
          child: Text('TRY AGAIN'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

// Usage example:
void showConnectivityErrorDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => ConnectivityErrorDialog(
      onRetry: () async {
        Navigator.of(context).pop();
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(child: CircularProgressIndicator()),
        );
        
        // Try to reconnect
        bool isConnected = await ConnectivityService().retryConnection();
        
        // Hide loading indicator
        Navigator.of(context).pop();
        
        if (!isConnected) {
          // Show the dialog again if still not connected
          showConnectivityErrorDialog(context);
        } else {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Connected to the internet!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onContinueOffline: () {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using app in offline mode'),
            duration: Duration(seconds: 3),
          ),
        );
      },
    ),
  );
}