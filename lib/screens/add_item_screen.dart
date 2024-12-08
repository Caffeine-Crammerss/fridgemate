import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../globals.dart';

class AddItemScreen extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onItemsAdded;

  const AddItemScreen({Key? key, required this.onItemsAdded}) : super(key: key);

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

  void _saveItems() {
    widget.onItemsAdded(itemsToBeAdded);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${itemsToBeAdded.length} items added successfully!")),
    );
    Navigator.pop(context, true); // Return `true` to indicate items were added
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
                      child: Image.file(item['image'],
                          width: 50, height: 50, fit: BoxFit.cover),
                    )
                        : const Icon(Icons.fastfood, size: 50, color: Colors.orange),
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
                          icon: const Icon(Icons.delete, color: Colors.red),
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

  const AddSingleItemDialog({Key? key, this.item}) : super(key: key);

  @override
  _AddSingleItemDialogState createState() => _AddSingleItemDialogState();
}

class _AddSingleItemDialogState extends State<AddSingleItemDialog> {
  final _itemNameController = TextEditingController();
  final _expiryDateController = TextEditingController();
  DateTime? _expiryDate;
  File? _itemImage;
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
      _itemImage = widget.item!['image'];
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
        _expiryDateController.text = DateFormat('yyyy-MM-dd').format(_expiryDate!);
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _itemImage = File(pickedFile.path);
      });
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _expiryDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Expiry Date",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                  child: _itemImage != null
                      ? Image.file(_itemImage!, fit: BoxFit.cover)
                      : const Center(child: Text("Add Photo (Optional)")),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (_itemNameController.text.isNotEmpty && _expiryDate != null) {
                    Navigator.pop(context, {
                      'name': _itemNameController.text,
                      'expiryDate': _expiryDate!,
                      'image': _itemImage,
                      'category': _selectedCategory,
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
