import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert'; // Add this import

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BluetoothProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: DeviceListScreen(),
          ),
          ElevatedButton(
            onPressed: () {
              Provider.of<BluetoothProvider>(context, listen: false).startScan();
            },
            child: Text('Scan for Devices'),
          ),
        ],
      ),
    );
  }
}

class DeviceListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, provider, child) {
        return ListView.builder(
          itemCount: provider.devices.length,
          itemBuilder: (context, index) {
            final device = provider.devices[index];
            return ListTile(
              title: Text(device.name.isEmpty ? 'Unknown Device' : device.name),
              subtitle: Text(device.id.toString()),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(device: device),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  final BluetoothDevice device;

  ChatScreen({required this.device});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<String> messages = [];

  @override
  void initState() {
    super.initState();
    _connectToDevice();
  }

  void _connectToDevice() async {
    await widget.device.connect();
    print("Connected to ${widget.device.name}");

    // Listen for incoming messages
    widget.device.discoverServices().then((services) {
      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.properties.read) {
            characteristic.read().then((value) {
              setState(() {
                messages.add("Received: ${String.fromCharCodes(value)}");
              });
            });
          }
        }
      }
    });
  }

  void _sendMessage(String message) async {
    final services = await widget.device.discoverServices();
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.write) {
          await characteristic.write(utf8.encode(message)); // Fixed line
          setState(() {
            messages.add("You: $message");
          });
          _messageController.clear();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with ${widget.device.name}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(hintText: "Type a message"),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    if (_messageController.text.isNotEmpty) {
                      _sendMessage(_messageController.text);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BluetoothProvider with ChangeNotifier {
  List<BluetoothDevice> devices = [];

  void startScan() {
    FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
    FlutterBluePlus.scanResults.listen((results) {
      for (var result in results) {
        if (!devices.contains(result.device)) {
          devices.add(result.device);
        }
      }
      notifyListeners();
    });
  }
}