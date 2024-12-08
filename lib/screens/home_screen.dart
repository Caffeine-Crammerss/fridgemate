import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../globals.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _profileImage;
  List<Map<String, dynamic>> recentItems = [];

  @override
  void initState() {
    super.initState();
    _updateRecentItems();
  }

  void _updateRecentItems() {
    setState(() {
      // Update the recentItems list with the last 4 items from the global itemList
      recentItems = itemList.length > 4
          ? itemList.sublist(itemList.length - 4)
          : List.from(itemList);
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _navigateToAddItemScreen() async {
    final result = await Navigator.pushNamed(context, '/addItem');
    if (result == true) {
      setState(() {
        // Update the recentItems list immediately
        recentItems = itemList.length > 4
            ? itemList.sublist(itemList.length - 4)
            : List.from(itemList);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: _buildDrawer(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[800]),
        title: Text(
          "Welcome, User!",
          style: TextStyle(color: Colors.grey[800], fontSize: 24, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                    child: _profileImage == null
                        ? Icon(Icons.account_circle, color: Colors.grey[400], size: 60)
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Your Name",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                ),
                Text(
                  "user@example.com",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Recent added items',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: recentItems.isNotEmpty
                ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3 / 2,
                ),
                itemCount: recentItems.length,
                itemBuilder: (context, index) {
                  final recentItem = recentItems[recentItems.length - 1 - index];
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recentItem['name'],
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Expires: ${DateFormat('yyyy-MM-dd').format(recentItem['expiryDate'])}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
                : const Center(
              child: Text(
                'No recent items added yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddItemScreen,
        backgroundColor: Colors.deepOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1E1E2C), Colors.deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? Icon(Icons.account_circle, color: Colors.grey[300], size: 40)
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  "Your Name",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.add_shopping_cart, "Add Items", () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/addItem');
          }),
          _buildDrawerItem(Icons.shopping_cart, "My Items", () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/myItems').then((_) {
              _updateRecentItems();
            });
          }),
          _buildDrawerItem(Icons.settings, "Settings", () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/settings');
          }),
          _buildDrawerItem(Icons.logout, "Log out", () {
            Navigator.pop(context);
            Navigator.pushReplacementNamed(context, '/');
          }),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[800]),
      title: Text(label, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }
}
