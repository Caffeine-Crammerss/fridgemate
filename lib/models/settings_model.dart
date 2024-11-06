import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FridgeMate',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  @override
  void initState() {
    super.initState();
    _firebaseMessaging.requestPermission();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message.notification?.title ?? 'Notification'),
      ));
    });
  }

  // Function to create user profile
  Future<void> createUserProfile(String userId, String name, String email) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).set({
      'user_id': userId,
      'name': name,
      'email': email,
      'preferences': [],
    });
  }

  // Function to add item to inventory
  Future<void> addItemToInventory(String userId, String itemName, int quantity, DateTime expirationDate) async {
    await FirebaseFirestore.instance.collection('inventory').add({
      'user_id': userId,
      'item_name': itemName,
      'quantity': quantity,
      'expiration_date': expirationDate.toIso8601String(),
    });
  }

  // Function to send expiration notification
  Future<void> sendExpirationNotification(String userId, String itemId, DateTime notificationDate) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'user_id': userId,
      'item_id': itemId,
      'notification_date': notificationDate.toIso8601String(),
    });
  }

  // Function to set user settings
  Future<void> setUserSettings(String userId, int notificationFrequency, List<String> displayPreferences) async {
    await FirebaseFirestore.instance.collection('settings').doc(userId).set({
      'user_id': userId,
      'notification_frequency': notificationFrequency,
      'display_preferences': displayPreferences,
    });
  }

  // Example usage of adding data
  void _exampleUsage() async {
    // Creating a user profile
    await createUserProfile('user123', 'John Doe', 'john.doe@example.com');

    // Adding an item to inventory
    await addItemToInventory('user123', 'Milk', 1, DateTime.now().add(Duration(days: 7)));

    // Setting user settings
    await setUserSettings('user123', 7, ['grid_view']);

    // Sending an expiration notification
    await sendExpirationNotification('user123', 'item123', DateTime.now().add(Duration(days: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FridgeMate'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _exampleUsage,
          child: Text('Run Example Code'),
        ),
      ),
    );
  }
}
