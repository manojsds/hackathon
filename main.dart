import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'api_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ApiService apiService = ApiService(
    baseUrl: 'http://192.168.13.41:5000',
  );
  bool _isLoggedIn = false;
  String _username = '';
  String _statusMessage = '';
  final TextEditingController _messageController = TextEditingController();

  static const String SERVICE_ID = "com.example.hackathon_app";
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Nearby().askLocationAndExternalStoragePermission(); // Removed because method not found
  }

  void _login(String username) {
    setState(() {
      _isLoggedIn = true;
      _username = username;
    });
    Navigator.of(context).pop();
  }

  void _showLoginDialog() {
    final TextEditingController _usernameController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Login'),
            content: TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Enter username'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (_usernameController.text.isNotEmpty) {
                    _login(_usernameController.text);
                  }
                },
                child: Text('Login'),
              ),
            ],
          ),
    );
  }

  void _sendEmergencyMessage() async {
    final message = _messageController.text;
    if (message.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter a message.';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Sending emergency message...';
    });

    bool backendSuccess = false;
    bool nearbySuccess = false;

    try {
      backendSuccess = await apiService.sendEmergencyMessage(message);
    } catch (e) {
      print('Error sending to backend: \$e');
      setState(() {
        _statusMessage = 'Error sending to backend: \$e';
      });
    }

    try {
      nearbySuccess = await _sendNearbyMessage(message);
    } catch (e) {
      print('Nearby send error: \$e');
      setState(() {
        _statusMessage = 'Nearby send error: \$e';
      });
    }

    setState(() {
      if (backendSuccess && nearbySuccess) {
        _statusMessage =
            'Message sent successfully to backend and nearby devices.';
      } else if (backendSuccess) {
        _statusMessage =
            'Message sent to backend but failed to send to nearby devices.';
      } else if (nearbySuccess) {
        _statusMessage =
            'Message sent to nearby devices but failed to send to backend.';
      } else {
        _statusMessage = 'Failed to send message.';
      }
    });
  }

  Future<bool> _sendNearbyMessage(String message) async {
    bool success = false;
    final strategy = Strategy.P2P_STAR;

    await Nearby().startAdvertising(
      SERVICE_ID,
      strategy,
      onConnectionInitiated: (id, info) {
        Nearby().acceptConnection(id, onPayloadReceived: (endid, payload) {});
      },
      onConnectionResult: (id, status) {
        if (status == Status.CONNECTED) {
          Nearby().sendBytesPayload(id, Uint8List.fromList(message.codeUnits));
          success = true;
        }
      },
      onDisconnected: (id) {},
    );

    await Nearby().startDiscovery(
      SERVICE_ID,
      strategy,
      onEndpointFound: (id, name, serviceId) {
        Nearby().requestConnection(
          _username,
          id,
          onConnectionInitiated: (id, info) {
            Nearby().acceptConnection(
              id,
              onPayloadRecieved: (endid, payload) {},
            );
          },
          onConnectionResult: (id, status) {
            if (status == Status.CONNECTED) {
              Nearby().sendBytesPayload(
                id,
                Uint8List.fromList(message.codeUnits),
              );
              success = true;
            }
          },
          onDisconnected: (id) {},
        );
      },
      onEndpointLost: (id) {},
    );

    await Future.delayed(Duration(seconds: 5));

    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();

    return success;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildBody() {
    if (_selectedIndex == 0) {
      return Center(
        child: ElevatedButton(
          onPressed: _sendEmergencyMessage,
          child: Text('Emergency'),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            textStyle: TextStyle(fontSize: 24),
          ),
        ),
      );
    } else if (_selectedIndex == 1) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _messageController,
              decoration: InputDecoration(labelText: 'Enter emergency message'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sendEmergencyMessage,
              child: Text('Send Emergency Message'),
            ),
            SizedBox(height: 16),
            Text(_statusMessage),
          ],
        ),
      );
    } else {
      return Center(child: Text('Menu'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Namma Suraksha',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Namma Suraksha'),
          actions: [
            if (!_isLoggedIn)
              IconButton(icon: Icon(Icons.login), onPressed: _showLoginDialog),
            if (_isLoggedIn)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(child: Text('Hello, \$_username')),
              ),
          ],
        ),
        drawer: Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              ListTile(
                leading: Icon(Icons.warning),
                title: Text('Emergency'),
                onTap: () {
                  Navigator.pop(context);
                  _sendEmergencyMessage();
                },
              ),
            ],
          ),
        ),
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
              icon: Icon(Icons.message),
              label: 'Message',
            ),
            BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.blue,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
