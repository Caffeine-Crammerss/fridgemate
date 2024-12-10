import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    _fetchItems(); // Fetch the user's items from Firestore
  }

  // Fetch items from Firestore (Assuming you have an 'items' collection)
  Future<void> _fetchItems() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        QuerySnapshot itemsSnapshot = await FirebaseFirestore.instance
            .collection('items')
            .where('userId', isEqualTo: user.uid) // Get items for the signed-in user
            .orderBy('createdAt', descending: true)
            .limit(4)
            .get();

        List<Map<String, dynamic>> items = [];
        itemsSnapshot.docs.forEach((doc) {
          items.add({
            'name': doc['name'],
            'expiryDate': doc['expiryDate'].toDate(),
          });
        });

        setState(() {
          recentItems = items;
        });
      } catch (e) {
        print('Error fetching items: $e');
      }
    }
  }

  void _updateRecentItems() {
    setState(() {
      // Update the recentItems list if necessary
      if (recentItems.length > 4) {
        recentItems = recentItems.sublist(recentItems.length - 4);
      }
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
        // Update recent items list after adding a new item
        _fetchItems();
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
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator(); // Show a loader while data is being fetched
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text(
                "Welcome, User",
                style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 24,
                    fontWeight: FontWeight.w600),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            return Text(
              "Welcome, ${userData['fullName'] ?? 'User'}",
              style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 24,
                  fontWeight: FontWeight.w600),
            );
          },
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        child: Icon(
                          Icons.account_circle,
                          color: Colors.grey.shade400,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Your Name",
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800),
                      ),
                      Text(
                        "user@example.com",
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                  );
                }

                final userData = snapshot.data!.data() as Map<String, dynamic>;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: _profileImage != null
                            ? FileImage(_profileImage!)
                            : null,
                        child: _profileImage == null
                            ? Icon(
                          Icons.account_circle,
                          color: Colors.grey.shade400,
                          size: 60,
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userData['fullName'] ?? "Your Name",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800),
                    ),
                    Text(
                      FirebaseAuth.instance.currentUser?.email ??
                          "user@example.com",
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey.shade600),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Recent added items',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: recentItems.isNotEmpty
                ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GridView.builder(
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 3 / 2,
                ),
                itemCount: recentItems.length,
                itemBuilder: (context, index) {
                  final recentItem = recentItems[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recentItem['name'] ?? 'Unnamed Item',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Expires: ${DateFormat('yyyy-MM-dd').format(recentItem['expiryDate'])}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey),
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
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return CircleAvatar(
                    radius: 30,
                    child: Icon(
                      Icons.account_circle,
                      size: 40,
                      color: Colors.grey.shade300,
                    ),
                  );
                }
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Icon(Icons.account_circle,
                          size: 40, color: Colors.grey.shade300),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userData['fullName'] ?? "Your Name",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                );
              },
            ),
          ),
          _buildDrawerItem(Icons.add_shopping_cart, "Add Items", () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/addItem');
          }),
          _buildDrawerItem(Icons.shopping_cart, "My Items", () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/myItems').then((_) {
              _fetchItems(); // Refresh items after navigating
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
      leading: Icon(icon, color: Colors.grey.shade800),
      title: Text(label, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
    );
  }
}
