import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../globals.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  File? _profileImage;
  String? _profileImageBase64;
  List<Map<String, dynamic>> recentItems = [];
  List<Map<String, dynamic>> notificationItems = [];
  bool hasUnreadNotifications = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _fetchProfilePhoto();
    _fetchItems();
  }

  Future<void> _fetchProfilePhoto() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && mounted) {
          setState(() {
            _profileImageBase64 = userDoc.get('profilePhoto');
          });
        }
      } catch (e) {
        print('Error fetching profile photo: $e');
      }
    }
  }

  void _checkExpiringItems() {
    notificationItems.clear();
    final now = DateTime.now();

    for (var item in itemList) {
      final expiryDate = item['expiryDate'] as DateTime;
      final daysUntilExpiry = expiryDate.difference(now).inDays;

      if (daysUntilExpiry < 0) {
        notificationItems.add({
          ...item,
          'message': 'has expired',
          'type': 'expired',
        });
      } else if (daysUntilExpiry <= 7) {
        notificationItems.add({
          ...item,
          'message': 'will expire in $daysUntilExpiry days',
          'type': 'expiring',
        });
      }
    }

    if (mounted && notificationItems.isNotEmpty) {
      setState(() {
        hasUnreadNotifications = true;
      });
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

        if (mounted) {
          setState(() {
            recentItems = itemsSnapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                'name': data['name'],
                'expiryDate': (data['expiryDate'] as Timestamp).toDate(),
                'category': data['category'],
                'image': data['image'],
              };
            }).take(4).toList();

            itemList = itemsSnapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return {
                'id': doc.id,
                'name': data['name'],
                'expiryDate': (data['expiryDate'] as Timestamp).toDate(),
                'category': data['category'],
                'image': data['image'],
              };
            }).toList();

            _checkExpiringItems();
          });
        }
      } catch (e) {
        print('Error fetching items: $e');
      }
    }
  }

  void _showNotificationsDialog() {
    setState(() {
      hasUnreadNotifications = false;
    });

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.notifications_active, color: Colors.deepOrange),
            const SizedBox(width: 10),
            const Text('Notifications'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: notificationItems.length,
            itemBuilder: (context, index) {
              final item = notificationItems[index];
              final bool isExpired = item['type'] == 'expired';

              return Card(
                color: isExpired ? Colors.red.shade50 : Colors.orange.shade50,
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isExpired ? Colors.red : Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isExpired ? Icons.warning : Icons.access_time,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    item['name'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isExpired ? Colors.red.shade900 : Colors.orange.shade900,
                    ),
                  ),
                  subtitle: Text(
                    'This item ${item['message']}',
                    style: TextStyle(
                      color: isExpired ? Colors.red.shade700 : Colors.orange.shade700,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(context, '/myItems');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
            ),
            child: const Text('View All Items'),
          ),
        ],
      ),
    );
  }

  Future<String?> _resizeAndEncodeImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) return null;

      final resized = img.copyResize(image, width: 300, height: 300);
      final compressed = img.encodeJpg(resized, quality: 85);
      return base64Encode(compressed);
    } catch (e) {
      print('Error processing image: $e');
      return null;
    }
  }

  Future<void> _pickImage({bool fromCamera = false}) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        final compressedImage = await _resizeAndEncodeImage(imageFile);

        if (compressedImage != null && mounted) {
          setState(() {
            _profileImage = imageFile;
            _profileImageBase64 = compressedImage;
          });

          await _saveProfileImageToFirestore(compressedImage);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error picking image: $e');
      }
    }
  }

  Future<void> _saveProfileImageToFirestore(String base64Image) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'profilePhoto': base64Image});
        _showSuccessSnackBar('Profile photo updated successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Error saving profile photo: $e');
    }
  }

  void _showProfilePhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(fromCamera: true);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_library, color: Colors.green),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(fromCamera: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToAddItemScreen() async {
    final result = await Navigator.pushNamed(context, '/addItem');
    if (result == true) {
      _fetchItems();
    }
  }

  void refreshRecentItems() {
    _fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[100],
      drawer: _buildModernDrawer(context),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(user),
          SliverToBoxAdapter(
            child: _buildProfileSection(),
          ),
          SliverToBoxAdapter(
            child: _buildQuickActions(),
          ),
          _buildRecentItemsHeader(),
          _buildRecentItemsGrid(),
        ],
      ),
    );
  }
  Widget _buildItemCard(Map<String, dynamic> item) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
              child: item['image'] != null
                  ? Image.memory(
                base64Decode(item['image']),
                fit: BoxFit.cover,
                width: double.infinity,
              )
                  : Image.asset(
                'assets/default_item_image.png',
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Exp: ${DateFormat('MMM d, y').format(item['expiryDate'])}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSliverAppBar(User? user) {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.menu, color: Colors.grey[800]),
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text("Welcome Back",
                  style: TextStyle(color: Colors.black87, fontSize: 16));
            }
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final firstName = userData['fullName']?.split(' ')[0];
            return Text(
              "Welcome back, ${firstName ?? 'User'}",
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        centerTitle: true,
      ),
      actions: [
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.deepOrange),
              onPressed: notificationItems.isEmpty ? null : _showNotificationsDialog,
            ),
            if (hasUnreadNotifications)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    notificationItems.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showProfilePhotoOptions,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.white,
                backgroundImage: _profileImageBase64 != null
                    ? MemoryImage(base64Decode(_profileImageBase64!))
                    : null,
                child: _profileImageBase64 == null
                    ? const Icon(Icons.person, size: 40, color: Colors.deepOrange)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final userData = snapshot.data?.data() as Map<String, dynamic>?;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userData?['fullName'] ?? 'Your Name',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      FirebaseAuth.instance.currentUser?.email ?? '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildQuickActionButton(
            icon: Icons.add_shopping_cart,
            label: "Add Items",
            onTap: _navigateToAddItemScreen,
            color: Colors.blue,
          ),
          _buildQuickActionButton(
            icon: Icons.inventory_2,
            label: "My Items",
            onTap: () => Navigator.pushNamed(context, '/myItems'),
            color: Colors.green,
          ),
          _buildQuickActionButton(
            icon: Icons.analytics,
            label: "Analytics",
            onTap: () => Navigator.pushNamed(context, '/dashboard'),
            color: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[800],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItemsHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Items',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/myItems'),
              child: const Text(
                'View All',
                style: TextStyle(color: Colors.deepOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentItemsGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: recentItems.isEmpty
          ? SliverToBoxAdapter(
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No items added yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      )
          : SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.85,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final item = recentItems[index];
            return _buildItemCard(item);
          },
          childCount: recentItems.length,
        ),
      ),
    );
  }

  Widget _buildModernDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepOrange.shade400,
              Colors.deepOrange.shade700,
            ],
          ),
        ),
        child: Column(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox(height: 100);
                final userData = snapshot.data?.data() as Map<String, dynamic>?;

                return UserAccountsDrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                  ),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: userData?['profilePhoto'] != null
                        ? MemoryImage(base64Decode(userData!['profilePhoto']))
                        : null,
                    child: userData?['profilePhoto'] == null
                        ? const Icon(Icons.person, color: Colors.deepOrange)
                        : null,
                  ),
                  accountName: Text(
                    userData?['fullName'] ?? 'Your Name',
                    style: const TextStyle(color: Colors.white),
                  ),
                  accountEmail: Text(
                    FirebaseAuth.instance.currentUser?.email ?? '',
                    style: const TextStyle(color: Colors.white70),
                  ),
                );
              },
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.only(top: 10),
                  children: [
                    _buildDrawerItem(
                      icon: Icons.add_shopping_cart,
                      title: 'Add Items',
                      onTap: () {
                        Navigator.pop(context);
                        _navigateToAddItemScreen();
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.inventory_2,
                      title: 'My Items',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/myItems');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.analytics,
                      title: 'Dashboard',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/dashboard');
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.settings,
                      title: 'Settings',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/settings');
                      },
                    ),
                    const Divider(color: Colors.grey),
                    _buildDrawerItem(
                      icon: Icons.logout,
                      title: 'Logout',
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushReplacementNamed(context, '/');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.deepOrange, size: 24),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      tileColor: Colors.transparent,
      hoverColor: Colors.deepOrange.withOpacity(0.1),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}