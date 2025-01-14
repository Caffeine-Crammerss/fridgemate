import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification settings
  final List<int> _notificationDaysOptions = [5, 7, 10, 14, 20, 30];
  int _selectedNotificationDays = 5;
  bool _isNotificationEnabled = true;

  // User profile
  String _userName = "Loading...";
  String _userEmail = "Loading...";
  String? _profileImageBase64;
  File? _userProfileImage;

  // Controllers
  final _newNameController = TextEditingController();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCompleteUserData();
  }

  @override
  void dispose() {
    _newNameController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompleteUserData() async {
    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          setState(() {
            _userName = userData['fullName'] ?? currentUser.displayName ?? 'User Name';
            _userEmail = currentUser.email ?? 'user@example.com';
            _profileImageBase64 = userData['profilePhoto'];
            _isNotificationEnabled = userData['notificationsEnabled'] ?? true;
            _selectedNotificationDays = userData['notificationDays'] ?? 5;
          });
        } else {
          setState(() {
            _userName = currentUser.displayName ?? 'User Name';
            _userEmail = currentUser.email ?? 'user@example.com';
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
      _showErrorSnackBar('Unable to load user information');
    }
  }

  void _showImagePickerOptions() {
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
                _pickProfileImage(fromCamera: true);
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
                _pickProfileImage(fromCamera: false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfileImage({bool fromCamera = false}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (image != null) {
      try {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);

        setState(() {
          _userProfileImage = File(image.path);
          _profileImageBase64 = base64Image;
        });

        await _saveProfileImageToFirestore(base64Image);
      } catch (e) {
        _showErrorSnackBar('Error processing image');
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
      _showErrorSnackBar('Error saving profile photo');
    }
  }

  void _updateNotificationSettings() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'notificationsEnabled': _isNotificationEnabled,
          'notificationDays': _selectedNotificationDays,
        });
        _showSuccessSnackBar('Notification settings updated');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating notification settings');
    }
  }

  void _showChangePasswordDialog() {
    // Reset controllers each time dialog is opened
    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _oldPasswordController,
                decoration: InputDecoration(
                  labelText: 'Old Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              onPressed: () async {
                // Validate inputs
                if (_newPasswordController.text != _confirmPasswordController.text) {
                  _showErrorSnackBar('New passwords do not match');
                  return;
                }

                try {
                  User? user = FirebaseAuth.instance.currentUser;
                  String email = user?.email ?? '';

                  // Re-authenticate with old password
                  await FirebaseAuth.instance.signInWithEmailAndPassword(
                    email: email,
                    password: _oldPasswordController.text,
                  );

                  // Validate new password
                  if (_newPasswordController.text.length < 6) {
                    _showErrorSnackBar('Password must be at least 6 characters');
                    return;
                  }

                  // Update password in Firebase Auth
                  await user?.updatePassword(_newPasswordController.text);

                  // Optional: Update password update timestamp in Firestore
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid)
                      .update({
                    'passwordUpdatedAt': FieldValue.serverTimestamp(),
                  });

                  _showSuccessSnackBar('Password changed successfully');
                  Navigator.of(context).pop();
                } on FirebaseAuthException catch (e) {
                  String errorMessage = 'An error occurred';
                  if (e.code == 'wrong-password') {
                    errorMessage = 'The old password is incorrect';
                  }
                  _showErrorSnackBar(errorMessage);
                } catch (e) {
                  _showErrorSnackBar('Failed to change password');
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          'Settings',
          style: TextStyle(
            color: Colors.deepOrange[800],
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.deepOrange[800]),
      ),
      body: CustomScrollView(
        slivers: [
          // Profile Section
          SliverToBoxAdapter(
            child: _buildProfileSection(),
          ),

          // Account Settings
          SliverToBoxAdapter(
            child: _buildSectionTitle('Account Settings'),
          ),
          SliverToBoxAdapter(
            child: _buildAccountSettings(),
          ),

          // Notification Settings
          SliverToBoxAdapter(
            child: _buildSectionTitle('Notifications'),
          ),
          SliverToBoxAdapter(
            child: _buildNotificationSettings(),
          ),

          // Feedback and Support Section
          SliverToBoxAdapter(
            child: _buildSectionTitle('Help & Support'),
          ),
          SliverToBoxAdapter(
            child: _buildHelpAndSupportSection(),
          ),
        ],
      ),
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
            onTap: _showImagePickerOptions,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.deepOrange[800],
        ),
      ),
    );
  }

  Widget _buildAccountSettings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsListTile(
            icon: Icons.person_outline,
            title: 'Edit Profile',
            onTap: _showUpdateNameDialog,
          ),
          _buildDivider(),
          _buildSettingsListTile(
            icon: Icons.lock_outline,
            title: 'Change Password',
            onTap: _showChangePasswordDialog,
          ),
          _buildDivider(),
          _buildSettingsListTile(
            icon: Icons.logout,
            title: 'Log Out',
            onTap: _handleLogout,
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Enable Notifications'),
            value: _isNotificationEnabled,
            activeColor: Colors.deepOrange,
            onChanged: (bool value) {
              setState(() {
                _isNotificationEnabled = value;
                _updateNotificationSettings();
              });
            },
            secondary: Icon(
              Icons.notifications_active,
              color: _isNotificationEnabled ? Colors.deepOrange : Colors.grey,
            ),
          ),
          _buildDivider(),
          ListTile(
            title: const Text('Expiration Notification'),
            subtitle: Text('$_selectedNotificationDays days before expiry'),
            trailing: DropdownButton<int>(
              value: _selectedNotificationDays,
              items: _notificationDaysOptions.map((days) {
                return DropdownMenuItem(
                  value: days,
                  child: Text('$days days'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedNotificationDays = value;
                    _updateNotificationSettings();
                  });
                }
              },
              underline: Container(), // Remove underline
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpAndSupportSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsListTile(
            icon: Icons.help_outline,
            title: 'Help Center',
            onTap: () {
              // TODO: Implement help center navigation
              _showComingSoonDialog();
            },
          ),
          _buildDivider(),
          _buildSettingsListTile(
            icon: Icons.feedback_outlined,
            title: 'Send Feedback',
            onTap: () {
              // TODO: Implement feedback mechanism
              _showComingSoonDialog();
            },
          ),
          _buildDivider(),
          _buildSettingsListTile(
            icon: Icons.info_outline,
            title: 'About App',
            onTap: () {
              _showAboutAppDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Coming Soon'),
          content: const Text('This feature is currently being developed. Stay tuned!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showAboutAppDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('About FridgeMate'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FridgeMate',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange[800],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 15),
              const Text(
                'FridgeMate helps you track and manage your food inventory, '
                    'reducing waste and helping you stay organized.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 15),
              const Text(
                '© 2024 FridgeMate. All rights reserved.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsListTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color ?? Colors.deepOrange[800],
      ),
      title: Text(
        title,
        style: TextStyle(color: color),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: color ?? Colors.deepOrange[800],
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.grey[300],
      indent: 16,
      endIndent: 16,
    );
  }

  void _showUpdateNameDialog() {
    _newNameController.text = _userName;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Update Name'),
          content: TextField(
            controller: _newNameController,
            decoration: InputDecoration(
              labelText: 'New Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              onPressed: () async {
                User? user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .update({'fullName': _newNameController.text});

                    setState(() {
                      _userName = _newNameController.text;
                    });

                    _showSuccessSnackBar('Name updated successfully');
                    Navigator.of(context).pop();
                  } catch (e) {
                    _showErrorSnackBar('Error updating name');
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                try {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/', // Replace with your login route
                        (Route<dynamic> route) => false,
                  );
                } catch (e) {
                  _showErrorSnackBar('Error logging out');
                }
              },
              child: const Text('Log Out'),
            ),
          ],
        );
      },
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