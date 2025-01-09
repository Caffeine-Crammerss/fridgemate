import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img; // For image compression
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../globals.dart'; // Ensure this file contains the global itemList variable

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  File? _profileImage;
  String? _profileImageBase64;
  List<Map<String, dynamic>> recentItems = [];

  @override
  void initState() {
    super.initState();
    _fetchProfilePhoto();
    _fetchItems();
  }

  // Method to refresh recent items from Firestore
  void refreshRecentItems() async {
    await _fetchItems();
  }

  Future<void> _fetchProfilePhoto() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          setState(() {
            _profileImageBase64 = userDoc['profilePhoto'];
            _profileImage = null; // Reset the local file reference
          });
        }
      } catch (e) {
        print('Error fetching profile photo: $e');
      }
    }
  }

  Future<void> _fetchItems() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        QuerySnapshot itemsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('items')
            .orderBy('createdAt', descending: true)
            .get();

        final fetchedItems = itemsSnapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'],
            'expiryDate': (data['expiryDate'] as Timestamp).toDate(),
            'category': data['category'],
            'photo': data['image'], // Use the 'image' field for item photos
          };
        }).toList();

        setState(() {
          recentItems = fetchedItems.take(4).toList();
          itemList = fetchedItems; // Update the global itemList variable
        });
      } catch (e) {
        print('Error fetching items: $e');
      }
    }
  }

  // Compress image and reduce size
  Future<String?> _resizeAndEncodeImage(File imageFile) async {
    try {
      final fileBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(fileBytes);
      if (originalImage == null) return null;

      final resizedImage = img.copyResize(
        originalImage,
        width: 300, // Resize to a width of 300px
        height: 300, // Resize to a height of 300px
      );

      final compressedImageBytes = img.encodeJpg(resizedImage, quality: 85); // Reduce quality
      return base64Encode(compressedImageBytes);
    } catch (e) {
      print('Error resizing image: $e');
      return null;
    }
  }

  Future<void> _pickImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (pickedFile != null) {
      final compressedBase64Image =
      await _resizeAndEncodeImage(File(pickedFile.path));

      if (compressedBase64Image != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
          _profileImageBase64 = compressedBase64Image;
        });

        await _saveProfileImageToFirestore(compressedBase64Image);
      }
    }
  }

  Future<void> _saveProfileImageToFirestore(String base64Image) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profilePhoto': base64Image});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated successfully!')),
      );
    } catch (e) {
      print('Error saving profile photo: $e');
    }
  }

  Future<void> _navigateToAddItemScreen() async {
    final result = await Navigator.pushNamed(context, '/addItem');
    if (result == true) {
      _fetchItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
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
              .doc(user?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Text(
                "Welcome Back, User",
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              );
            }

            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final firstName = userData['fullName']?.split(' ')[0];
            return Text(
              "Welcome Back, ${firstName ?? 'User'}",
              style: TextStyle(
                color: Colors.grey.shade800,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            );
          },
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
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera),
                              title: const Text('Take Photo'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage(fromCamera: true);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Choose from Gallery'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage(fromCamera: false);
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : (_profileImageBase64 != null
                        ? MemoryImage(base64Decode(_profileImageBase64!))
                        : null),
                    child: (_profileImage == null && _profileImageBase64 == null)
                        ? const Icon(
                      Icons.account_circle,
                      color: Colors.grey,
                      size: 70,
                    )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }
                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Text("Your Name");
                    }

                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                    return Text(
                      userData['fullName'] ?? "Your Name",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 5),
                Text(
                  user?.email ?? "user@example.com",
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Text(
            'Recent added items',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: recentItems.isNotEmpty
                ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: GridView.builder(
                itemCount: recentItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) {
                  final item = recentItems[index];
                  final itemPhotoBase64 = item['photo'];

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Text(
                            item['name'] ?? "Unnamed Item",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Text(
                            'Expires: ${DateFormat('yyyy-MM-dd').format(item['expiryDate'])}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            child: itemPhotoBase64 != null
                                ? Image.memory(
                              base64Decode(itemPhotoBase64),
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                                : const Center(child: Text('No Image')),
                          ),
                        ),
                      ],
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
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                  ),
                  child: Text("User"),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              return DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1E1E2C), Colors.deepOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundImage: userData['profilePhoto'] != null
                          ? MemoryImage(base64Decode(userData['profilePhoto']))
                          : null,
                      child: userData['profilePhoto'] == null
                          ? const Icon(
                        Icons.account_circle,
                        size: 40,
                        color: Colors.grey,
                      )
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      userData['fullName'] ?? "Your Name",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          _buildDrawerItem(Icons.add_shopping_cart, "Add Items", () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/addItem');
          }),
          _buildDrawerItem(Icons.shopping_cart, "My Items", () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/myItems');
          }),
          _buildDrawerItem(Icons.settings, "Settings", () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/settings');
          }),
          const Divider(),
          _buildDrawerItem(Icons.logout, "Log Out", () {
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
      title: Text(label),
      onTap: onTap,
    );
  }
}
