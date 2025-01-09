import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../globals.dart';

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
    );
    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _base64Image = null; // Clear existing base64Image to prioritize the new image
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Edit Item",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Item Name",
                  border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: "Expiry Date",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: categories.map((category) {
                  return DropdownMenuItem(value: category, child: Text(category));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _selectedImage != null
                      ? Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                  )
                      : (_base64Image != null
                      ? Image.memory(
                    base64Decode(_base64Image!),
                    fit: BoxFit.cover,
                  )
                      : const Center(child: Text("Tap to add/change photo"))),
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
                          : _base64Image, // Use base64Image if no new image is selected
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please complete all required fields.")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Save"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  late List<Map<String, dynamic>> allItems;

  void _deleteItem(String itemId) async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Optimistically update the UI
        setState(() {
          allItems.removeWhere((item) => item['id'] == itemId);
        });

        // Delete item from Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('items')
            .doc(itemId)
            .delete();

        widget.refreshHomeScreen(); // Notify HomeScreen

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item deleted successfully!')),
        );
      }
    } catch (e) {
      print('Error deleting item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting item')),
      );
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
          // Update Firestore
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('items')
              .doc(itemId)
              .update(updatedItem);

          // Update local `allItems` list
          setState(() {
            final index = allItems.indexWhere((i) => i['id'] == itemId);
            if (index != -1) {
              allItems[index] = {...allItems[index], ...updatedItem};
            }
          });

          widget.refreshHomeScreen(); // Notify HomeScreen

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item updated successfully!')),
          );
        }
      } catch (e) {
        print('Error updating item: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating item')),
        );
      }
    }
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
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No items found.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        allItems = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();

        return DefaultTabController(
          length: categories.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('My Items', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.deepOrange,
              bottom: TabBar(
                isScrollable: true,
                tabs: categories.map((category) => Tab(text: category)).toList(),
              ),
            ),
            body: TabBarView(
              children: categories.map((category) {
                final itemsInCategory =
                allItems.where((item) => item['category'] == category).toList();

                return itemsInCategory.isEmpty
                    ? const Center(
                  child: Text(
                    'No items in this category.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(10.0),
                  itemCount: itemsInCategory.length,
                  itemBuilder: (context, index) {
                    final item = itemsInCategory[index];
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
                      expiryText = "${daysUntilExpiry + 1} days until expiry"; // Adding 1 to include the current day
                      expiryColor =
                      daysUntilExpiry <= 10 ? Colors.orange : Colors.green;
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
                                    _deleteItem(item['id']);
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
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
