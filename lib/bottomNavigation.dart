import 'package:ah_ticketing_prod/AppServices/AppService.dart';
import 'package:ah_ticketing_prod/AppServices/connectivityService.dart';
import 'package:ah_ticketing_prod/Widgets/bottonNav.dart';
import 'package:ah_ticketing_prod/chatsList.dart';
import 'package:ah_ticketing_prod/customerQuery.dart';
import 'package:flutter/material.dart';

class BottomNavigationScreen extends StatefulWidget {
  const BottomNavigationScreen({Key? key}) : super(key: key);

  @override
  _BottomNavigationScreenState createState() => _BottomNavigationScreenState();
}

class _BottomNavigationScreenState extends State<BottomNavigationScreen> {
  int _selectedIndex = 0;
    final ConnectivityService _connectivityService = ConnectivityService();
  bool _isOffline = false;

  // List of screens to be displayed
  final List<Widget> _screens = [
    const InboxScreen(),
    const ChatQueryAdmin(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _retryConnection() async {
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Checking connection...'), duration: Duration(seconds: 1)),
    );
    
    bool isConnected = await _connectivityService.retryConnection();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isConnected 
            ? 'Connected to the internet!' 
            : 'Still offline. Please check your connection.'),
        backgroundColor: isConnected ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _connectivityService.initialize();
    _connectivityService.connectionStatus.listen((isConnected) {
      setState(() {
        _isOffline = !isConnected;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_selectedIndex],
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: AnimatedOpacity(
                opacity: _isOffline ? 1.0 : 0.0,
                duration: Duration(milliseconds: 300),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  height: _isOffline ? null : 0,
                  child: Material(
                    elevation: 4,
                    color: Colors.red.shade700,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.white, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You\'re offline. App will work in offline mode.',
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ),
                          TextButton(
                            onPressed: _retryConnection,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              minimumSize: Size(0, 0),
                            ),
                            child: Text(
                              'RETRY',
                              style: TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: EnhancedBottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: _onItemTapped,
        primaryColor: AppColors.purple,
      ),
    );
  }

}