import 'package:flutter/material.dart';
import 'dart:convert'; // For base64 encoding
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img; // For image compression
import '../globals.dart';

class AddItemScreen extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onItemsAdded;

  const AddItemScreen({super.key, required this.onItemsAdded});

  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  List<Map<String, dynamic>> itemsToBeAdded = [];

  void _showAddItemDialog({Map<String, dynamic>? item, int? index}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddSingleItemDialog(item: item),
    );

    if (result != null) {
      setState(() {
        if (index != null) {
          // Update existing item
          itemsToBeAdded[index] = result;
        } else {
          // Add new item
          itemsToBeAdded.add(result);
        }
      });
    }
  }

  void _saveItems() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        final itemsRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('items');

        for (var item in itemsToBeAdded) {
          await itemsRef.add({
            'name': item['name'],
            'expiryDate': item['expiryDate'],
            'category': item['category'],
            'image': item['image'],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        setState(() {
          itemsToBeAdded.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Items added successfully!")),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save items: $e")),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not authenticated.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("To Be Added Items"),
        backgroundColor: Colors.deepOrange,
      ),
      body: Column(
        children: [
          Expanded(
            child: itemsToBeAdded.isEmpty
                ? const Center(
              child: Text(
                "No items to be added.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(10.0),
              itemCount: itemsToBeAdded.length,
              itemBuilder: (context, index) {
                final item = itemsToBeAdded[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 4,
                  child: ListTile(
                    leading: item['image'] != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(item['image']),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    )
                        : const Icon(Icons.fastfood,
                        size: 50, color: Colors.orange),
                    title: Text(
                      item['name'] ?? "Unnamed Item",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                        "Category: ${item['category']}, Expires on: ${DateFormat('yyyy-MM-dd').format(item['expiryDate'])}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            _showAddItemDialog(item: item, index: index);
                          },
                        ),
                        IconButton(
                          icon:
                          const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              itemsToBeAdded.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showAddItemDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Add Item",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: itemsToBeAdded.isNotEmpty ? _saveItems : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Save/Proceed",
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddSingleItemDialog extends StatefulWidget {
  final Map<String, dynamic>? item;

  const AddSingleItemDialog({super.key, this.item});

  @override
  _AddSingleItemDialogState createState() => _AddSingleItemDialogState();
}

class _AddSingleItemDialogState extends State<AddSingleItemDialog> {
  final _itemNameController = TextEditingController();
  final _expiryDateController = TextEditingController();
  DateTime? _expiryDate;
  String? _imageBase64;
  String _selectedCategory = "Fruits";

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _itemNameController.text = widget.item!['name'] ?? "";
      _expiryDate = widget.item!['expiryDate'];
      _expiryDateController.text = _expiryDate != null
          ? DateFormat('yyyy-MM-dd').format(_expiryDate!)
          : "";
      _imageBase64 = widget.item!['image'];
      _selectedCategory = widget.item!['category'] ?? "Fruits";
    }
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
        _expiryDateController.text =
            DateFormat('yyyy-MM-dd').format(_expiryDate!);
      });
    }
  }

  Future<void> _pickImage({bool fromCamera = false}) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (pickedFile != null) {
      final fileBytes = await pickedFile.readAsBytes();

      // Resize and compress the image
      img.Image? originalImage = img.decodeImage(fileBytes);
      if (originalImage != null) {
        img.Image resizedImage =
        img.copyResize(originalImage, width: 300, height: 300);
        final compressedBytes =
        img.encodeJpg(resizedImage, quality: 85); // Quality between 0 and 100

        setState(() {
          _imageBase64 = base64Encode(compressedBytes);
        });
      }
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Add/Edit Item",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _itemNameController,
                decoration: InputDecoration(
                  labelText: "Item Name",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _expiryDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Expiry Date",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () => _selectExpiryDate(context),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
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
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton(
                    onPressed: () => _pickImage(fromCamera: true),
                    child: const Text("Take Photo"),
                  ),
                  ElevatedButton(
                    onPressed: () => _pickImage(),
                    child: const Text("Upload Photo"),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_imageBase64 != null)
                Image.memory(
                  base64Decode(_imageBase64!),
                  height: 150,
                  fit: BoxFit.cover,
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_itemNameController.text.isNotEmpty &&
                      _expiryDate != null) {
                    Navigator.pop(context, {
                      'name': _itemNameController.text,
                      'expiryDate': _expiryDate!,
                      'image': _imageBase64,
                      'category': _selectedCategory,
                    });
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                          Text("Please complete all required fields.")),
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
