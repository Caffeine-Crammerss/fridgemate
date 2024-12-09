//Esed from android studio
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart'; // Import HomeScreen
import 'screens/settings_screen.dart';
import 'screens/add_item_screen.dart';
import 'screens/my_items_screen.dart' as my_items; // Import MyItemsScreen with alias
import 'globals.dart'; // Import globals to access itemList

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(FridgeMateApp());
}
class FridgeMateApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FridgeMate',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: '/home',
      routes: {
        '/': (context) => const AuthScreen(),
        '/home': (context) => const HomeScreen(), // HomeScreen uses the global `itemList`
        '/settings': (context) => SettingsScreen(),
        '/addItem': (context) => AddItemScreen(
          onItemsAdded: (newItems) {
            itemList.addAll(newItems); // Access the global `itemList` here
          },
        ),
        '/myItems': (context) => const my_items.MyItemsScreen(), // MyItemsScreen uses the global `itemList`
      },
    );
  }
}
