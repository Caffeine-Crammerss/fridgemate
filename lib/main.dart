import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart'; // Import HomeScreen with the corrected state
import 'screens/settings_screen.dart';
import 'screens/add_item_screen.dart';
import 'screens/my_items_screen.dart'; // Import MyItemsScreen
import 'globals.dart'; // Ensure this file contains `itemList` and `categories`

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(FridgeMateApp());
}

class FridgeMateApp extends StatelessWidget {
  // Define a GlobalKey for HomeScreen
  final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

  FridgeMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FridgeMate',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthScreen(),
        '/home': (context) => HomeScreen(key: homeScreenKey),
        '/settings': (context) => const SettingsScreen(),
        '/addItem': (context) => AddItemScreen(
          onItemsAdded: (newItems) {
            itemList.addAll(newItems); // Update the global itemList
            homeScreenKey.currentState?.refreshRecentItems(); // Refresh HomeScreen
          },
        ),
        '/myItems': (context) => MyItemsScreen(
          refreshHomeScreen: () {
            homeScreenKey.currentState?.refreshRecentItems();
          },
        ),
      },
    );
  }
}
