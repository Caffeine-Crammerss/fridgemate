import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fridgemate/screens/splash_screen.dart';
import 'package:fridgemate/screens/dashboard_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart'; // Import HomeScreen with the corrected state
import 'screens/settings_screen.dart';
import 'screens/add_item_screen.dart';
import 'screens/my_items_screen.dart'; // Import MyItemsScreen
import 'globals.dart'; // Ensure this file contains `itemList` and `categories`

//main -Basel, FridgeMate 1.0.0v
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(FridgeMateApp());
}

class FridgeMateApp extends StatelessWidget {
  // Define a GlobalKey for HomeScreen
  final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fridge_Mate',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),  // Changed initial route to SplashScreen
        '/auth': (context) => const AuthScreen(),  // Added auth route
        '/home': (context) => HomeScreen(key: homeScreenKey),
        '/settings': (context) => const SettingsScreen(),
        '/dashboard': (context) => const DashboardScreen(),
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