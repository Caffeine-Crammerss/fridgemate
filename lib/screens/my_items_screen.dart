import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../globals.dart';
// Basel was here (:
class MyItemsScreen extends StatefulWidget {
  final VoidCallback refreshHomeScreen;

  const MyItemsScreen({Key? key, required this.refreshHomeScreen})
      : super(key: key);

  @override
  _MyItemsScreenState createState() => _MyItemsScreenState();
}

class EditItemDialog extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditItemDialog({Key? key, required this.item}) : super(key: key);

  @override
  _EditItemDialogState createState() => _EditItemDialogState();
}

class _EditItemDialogState extends State<EditItemDialog> {
  final TextEditingController _nameController = TextEditingController();
  DateTime? _expiryDate;
  String _selectedCategory = "Fruits";
  String? _base64Image;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.item['name'] ?? "";
    _expiryDate = (widget.item['expiryDate'] as Timestamp).toDate();
    _selectedCategory = widget.item['category'] ?? "Fruits";
    _base64Image = widget.item['image'];
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepOrange,
              primary: Colors.deepOrange,
              surface: Colors.white,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _base64Image = null; // Clear existing base64Image to prioritize the new image
      });
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.deepOrange),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.deepOrange),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepOrange.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Edit Item",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepOrange.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: "Item Name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.food_bank_outlined),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _selectExpiryDate(context),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: TextEditingController(
                        text: _expiryDate != null
                            ? DateFormat('yyyy-MM-dd').format(_expiryDate!)
                            : "",
                      ),
                      decoration: InputDecoration(
                        labelText: "Expiry Date",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: const Icon(Icons.calendar_today),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  items: categories.map((category) {
                    return DropdownMenuItem(
                        value: category,
                        child: Text(category)
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: "Category",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.category_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _showImagePickerOptions,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                        : (_base64Image != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(_base64Image!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                        : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            color: Colors.deepOrange.shade300,
                            size: 50,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Tap to add/change photo",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_nameController.text.isNotEmpty && _expiryDate != null) {
                      Navigator.pop(context, {
                        'name': _nameController.text,
                        'expiryDate': _expiryDate!,
                        'category': _selectedCategory,
                        'image': _selectedImage != null
                            ? base64Encode(_selectedImage!.readAsBytesSync())
                            : _base64Image,
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Please complete all required fields."),
                          backgroundColor: Colors.deepOrange.shade400,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MyItemsScreenState extends State<MyItemsScreen> with SingleTickerProviderStateMixin {
  late List<Map<String, dynamic>> _allItems = [];
  String _filterStatus = 'All';
  late TabController _tabController;
  late List<String> _allCategories;

  @override
  void initState() {
    super.initState();
    _allCategories = ['All', ...categories];
    _tabController = TabController(length: _allCategories.length, vsync: this);

    // Add listener to reset filter when changing tabs
    _tabController.addListener(() {
      if (_tabController.index != 0 && _filterStatus != 'All') {
        setState(() {
          _filterStatus = 'All';
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getItemStatus(Map<String, dynamic> item) {
    final expiryTimestamp = item['expiryDate'] as Timestamp;
    final expiryDate = expiryTimestamp.toDate();
    final today = DateTime.now();

    if (expiryDate.isBefore(today)) {
      return 'Expired';
    } else {
      final daysUntilExpiry = expiryDate.difference(today).inDays;
      return daysUntilExpiry <= 10 ? 'About to Expire' : 'Valid';
    }
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'Filter Items',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text('All Items'),
                trailing: _filterStatus == 'All'
                    ? const Icon(Icons.check, color: Colors.deepOrange)
                    : null,
                onTap: () {
                  setState(() {
                    _filterStatus = 'All';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Expired Items'),
                trailing: _filterStatus == 'Expired'
                    ? const Icon(Icons.check, color: Colors.deepOrange)
                    : null,
                onTap: () {
                  setState(() {
                    _filterStatus = 'Expired';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('About to Expire'),
                trailing: _filterStatus == 'About to Expire'
                    ? const Icon(Icons.check, color: Colors.deepOrange)
                    : null,
                onTap: () {
                  setState(() {
                    _filterStatus = 'About to Expire';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('Valid Items'),
                trailing: _filterStatus == 'Valid'
                    ? const Icon(Icons.check, color: Colors.deepOrange)
                    : null,
                onTap: () {
                  setState(() {
                    _filterStatus = 'Valid';
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete "${item['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete == true) {
      try {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          setState(() {
            _allItems.removeWhere((i) => i['id'] == item['id']);
          });

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('items')
              .doc(item['id'])
              .delete();

          widget.refreshHomeScreen();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item['name']} deleted successfully!'),
              backgroundColor: Colors.deepOrange.shade400,
              duration: const Duration (seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error deleting item: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error deleting item'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  void _editItem(Map<String, dynamic> item, String itemId) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditItemDialog(item: item),
    );

    if (result != null) {
      final updatedItem = result;

      try {
        final User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('items')
              .doc(itemId)
              .update(updatedItem);

          // Update local `_allItems` list
          setState(() {
            final index = _allItems.indexWhere((i) => i['id'] == itemId);
            if (index != -1) {
              _allItems[index] = {..._allItems[index], ...updatedItem};
            }
          });

          widget.refreshHomeScreen(); // Notify HomeScreen

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Item updated successfully!'),
              backgroundColor: Colors.deepOrange.shade400,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('Error updating item: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error updating item'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  Widget _buildItemList(List<Map<String, dynamic>> itemsToShow) {
    // Filter items based on status when in All tab
    if (_filterStatus != 'All') {
      itemsToShow = itemsToShow.where((item) =>
      _getItemStatus(item) == _filterStatus
      ).toList();
    }

    return itemsToShow.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.kitchen,
            size: 100,
            color: Colors.deepOrange.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            _filterStatus == 'All'
                ? 'No items found.'
                : 'No ${_filterStatus.toLowerCase()} items.',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first item to get started!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    )
        : ListView.builder(
      padding: const EdgeInsets.all(10.0),
      itemCount: itemsToShow.length,
      itemBuilder: (context, index) {
        final item = itemsToShow[index];
        final expiryTimestamp = item['expiryDate'] as Timestamp;
        final expiryDate = expiryTimestamp.toDate();
        final expired = expiryDate.isBefore(DateTime.now());

        // Calculate days until expiry or days since expiration
        final today = DateTime.now();
        final daysUntilExpiry = expiryDate.difference(today).inDays;
        final expiredDaysAgo = today.difference(expiryDate).inDays;

        // Determine expiry text and color
        String expiryText;
        Color expiryColor;

        if (expired) {
          expiryText = expiredDaysAgo == 0
              ? "Expired today"
              : "Expired ${expiredDaysAgo} days ago";
          expiryColor = Colors.red;
        } else {
          expiryText = "${daysUntilExpiry + 1} days until expiry";
          expiryColor = daysUntilExpiry <= 10 ? Colors.orange : Colors.green;
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          elevation: 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Section with Border
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.grey.shade400, width: 1.5),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                  child: item['image'] != null
                      ? Image.memory(
                    base64Decode(item['image']),
                    height: 100,
                    width: 100,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    height: 100,
                    width: 100,
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.fastfood,
                      size: 50,
                      color: Colors.orange,
                    ),
                  ),
                ),
              ),
              // Details Section
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name'] ?? "Unnamed Item",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Category: ${item['category']}",
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Expiry Date: ${DateFormat('MM/dd/yyyy').format(expiryDate)}",
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        expiryText,
                        style: TextStyle(
                          fontSize: 12,
                          color: expiryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Actions Section
              Padding(
                padding: const EdgeInsets.only(
                    right: 8.0, top: 8.0),
                child: Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit,
                          color: Colors.blue, size: 20),
                      onPressed: () {
                        _editItem(item, item['id']);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete,
                          color: Colors.red, size: 20),
                      onPressed: () {
                        _deleteItem(item);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text('User not authenticated'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('items')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepOrange),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.kitchen,
                  size: 100,
                  color: Colors.deepOrange.shade200,
                ),
                const SizedBox(height: 16),
                Text(
                  'No items found.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first item to get started!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        _allItems = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        return DefaultTabController(
          length: _allCategories.length,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                'My Items',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black26,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
              ),
              backgroundColor: Colors.deepOrange,
              elevation: 0,
              actions: [
                // Only show filter icon in the "All" tab
                Builder(
                  builder: (context) {
                    return DefaultTabController.of(context).index == 0
                        ? IconButton(
                      icon: const Icon(Icons.filter_list),
                      onPressed: _showFilterOptions,
                    )
                        : const SizedBox.shrink();
                  },
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Colors.white.withOpacity(0.2),
                ),
                labelStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                ),
                tabs: _allCategories.map((category) => Tab(text: category)).toList(),
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: _allCategories.map((category) {
                final itemsToShow = category == 'All'
                    ? _allItems
                    : _allItems.where((item) => item['category'] == category).toList();

                return _buildItemList(itemsToShow);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}