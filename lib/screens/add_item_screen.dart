import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import '../globals.dart';

class AddItemScreen extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onItemsAdded;

  const AddItemScreen({Key? key, required this.onItemsAdded}) : super(key: key);

  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  List<Map<String, dynamic>> itemsToBeAdded = [];

  // Barcode scanning method
  Future<void> _scanBarcode() async {
    await showDialog(
      context: context,
      builder: (context) => BarcodeScannerDialog(
        onBarcodeDetected: (barcode) {
          Navigator.of(context).pop();
          _fetchProductDetails(barcode);
        },
      ),
    );
  }

  // Method to fetch product details from an API
  Future<void> _fetchProductDetails(String barcode) async {
    try {
      // Example API call (you'll need to replace with an actual product database API)
      final response = await http.get(
          Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json')
      );

      if (response.statusCode == 200) {
        final productData = json.decode(response.body);

        // Check if product exists
        if (productData['status'] == 1) {
          final product = productData['product'];

          // Prepare item details
          final itemToAdd = {
            'name': product['product_name'] ?? 'Unknown Product',
            'category': _extractCategory(product),
            'expiryDate': _calculateExpiryDate(),
            'image': null,
            'barcode': barcode
          };

          // Show dialog to confirm or edit item details
          final confirmedItem = await _showAddItemDialog(
            item: itemToAdd,
          );

          if (confirmedItem != null) {
            setState(() {
              itemsToBeAdded.add(confirmedItem);
            });
          }
        } else {
          // If product not found, open dialog to manually add
          final manualItem = await _showAddItemDialog(
              item: {'barcode': barcode}
          );

          if (manualItem != null) {
            setState(() {
              itemsToBeAdded.add(manualItem);
            });
          }
        }
      } else {
        // API call failed, open manual entry
        final manualItem = await _showAddItemDialog(
            item: {'barcode': barcode}
        );

        if (manualItem != null) {
          setState(() {
            itemsToBeAdded.add(manualItem);
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error fetching product details: $e');
    }
  }

  // Extract category from product data
  String _extractCategory(Map<String, dynamic> product) {
    if (product['categories_tags'] != null &&
        (product['categories_tags'] as List).isNotEmpty) {
      return (product['categories_tags'][0] as String)
          .split(':')
          .last
          .trim();
    }
    return 'Other';
  }

  // Calculate default expiry date
  DateTime _calculateExpiryDate() {
    return DateTime.now().add(const Duration(days: 30));
  }

  // Show add/edit item dialog
  Future<Map<String, dynamic>?> _showAddItemDialog({
    Map<String, dynamic>? item,
    int? index,
  }) async {
    return await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddSingleItemDialog(
        item: item,
        onScanBarcode: _scanBarcode,
      ),
    );
  }

  // Save items to Firestore
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
            'barcode': item['barcode'] ?? '',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        setState(() {
          itemsToBeAdded.clear();
        });

        _showSuccessSnackBar("Items added successfully!");
        Navigator.pop(context, true);
      } catch (e) {
        _showErrorSnackBar("Failed to save items: $e");
      }
    } else {
      _showErrorSnackBar("User not authenticated.");
    }
  }

  // Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.deepOrange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Add Items",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: itemsToBeAdded.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_shopping_cart,
                    size: 100,
                    color: Colors.deepOrange.shade200,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No items to be added",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap 'Add Item' or scan a barcode",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(10.0),
              itemCount: itemsToBeAdded.length,
              itemBuilder: (context, index) {
                final item = itemsToBeAdded[index];
                return Container(
                  margin: const EdgeInsets.symmetric(
                      vertical: 8.0, horizontal: 4.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        Colors.deepOrange.shade50,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: item['image'] != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        base64Decode(item['image']),
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    )
                        : CircleAvatar(
                      backgroundColor: Colors.deepOrange.shade100,
                      child: Icon(
                        Icons.fastfood,
                        color: Colors.deepOrange.shade400,
                      ),
                    ),
                    title: Text(
                      item['name'] ?? "Unnamed Item",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      "Category: ${item['category']}\nExpires: ${DateFormat('yyyy-MM-dd').format(item['expiryDate'])}",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            color: Colors.blue.shade300,
                          ),
                          onPressed: () async {
                            final editedItem = await _showAddItemDialog(
                              item: item,
                              index: index,
                            );
                            if (editedItem != null) {
                              setState(() {
                                itemsToBeAdded[index] = editedItem;
                              });
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Colors.red.shade300,
                          ),
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
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final newItem = await _showAddItemDialog();
                      if (newItem != null) {
                        setState(() {
                          itemsToBeAdded.add(newItem);
                        });
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add Item"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: itemsToBeAdded.isNotEmpty ? _saveItems : null,
                    icon: const Icon(Icons.save),
                    label: const Text("Save All"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
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
  final VoidCallback? onScanBarcode;

  const AddSingleItemDialog({
    Key? key,
    this.item,
    this.onScanBarcode,
  }) : super(key: key);

  @override
  _AddSingleItemDialogState createState() => _AddSingleItemDialogState();
}

class _AddSingleItemDialogState extends State<AddSingleItemDialog> {
  final _itemNameController = TextEditingController();
  final _expiryDateController = TextEditingController();
  DateTime? _expiryDate;
  String? _imageBase64;
  String _selectedCategory = "Fruits";
  String? _barcode;

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _itemNameController.text = widget.item!['name'] ?? "";
      _expiryDate = widget.item!['expiryDate'] ?? DateTime.now();
      _expiryDateController.text = DateFormat('yyyy-MM-dd').format(_expiryDate!);
      _imageBase64 = widget.item!['image'];
      _selectedCategory = widget.item!['category'] ?? "Fruits";
      _barcode = widget.item!['barcode'];
    }
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
    if (picked != null && mounted) {
      setState(() {
        _expiryDate = picked;
        _expiryDateController.text = DateFormat('yyyy-MM-dd').format(_expiryDate!);
      });
    }
  }

  Future<void> _pickImage({bool fromCamera = false}) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );

      if (pickedFile != null) {
        final fileBytes = await pickedFile.readAsBytes();

        // Resize and compress the image
        img.Image? originalImage = img.decodeImage(fileBytes);
        if (originalImage != null) {
          img.Image resizedImage = img.copyResize(
            originalImage,
            width: 300,
            height: 300,
          );
          final compressedBytes = img.encodeJpg(resizedImage, quality:85);

          setState(() {
            _imageBase64 = base64Encode(compressedBytes);
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
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
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Add/Edit Item",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange.shade700,
                      ),
                    ),
                    if (widget.onScanBarcode != null)
                      IconButton(
                        icon: Icon(
                          Icons.qr_code_scanner,
                          color: Colors.deepOrange.shade300,
                        ),
                        onPressed: widget.onScanBarcode,
                        tooltip: 'Scan Barcode',
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Barcode display (if from barcode scan)
                if (_barcode != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      "Barcode: $_barcode",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                TextField(
                  controller: _itemNameController,
                  decoration: InputDecoration(
                    labelText: "Item Name",
                    prefixIcon: Icon(
                      Icons.food_bank_outlined,
                      color: Colors.deepOrange.shade300,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _expiryDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Expiry Date",
                    prefixIcon: Icon(
                      Icons.calendar_today,
                      color: Colors.deepOrange.shade300,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.edit_calendar,
                        color: Colors.deepOrange.shade300,
                      ),
                      onPressed: () => _selectExpiryDate(context),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: "Category",
                    prefixIcon: Icon(
                      Icons.category_outlined,
                      color: Colors.deepOrange.shade300,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
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
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 360 ?
                      MediaQuery.of(context).size.width * 0.35 : 140,
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(fromCamera: true),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text(
                          "Take Photo",
                          style: TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange.shade300,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width < 360 ?
                      MediaQuery.of(context).size.width * 0.35 : 140,
                      child: ElevatedButton.icon(
                        onPressed: () => _pickImage(),
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text(
                          "Upload Photo",
                          style: TextStyle(fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade300,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_imageBase64 != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.memory(
                      base64Decode(_imageBase64!),
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (_itemNameController.text.isNotEmpty &&
                        _expiryDate != null) {
                      Navigator.pop(context, {
                        'name': _itemNameController.text,
                        'expiryDate': _expiryDate!,
                        'image': _imageBase64,
                        'category': _selectedCategory,
                        'barcode': _barcode,
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Please complete all required fields."),
                          backgroundColor: Colors.red.shade400,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    "Save Item",
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

class BarcodeScannerDialog extends StatefulWidget {
  final Function(String) onBarcodeDetected;

  const BarcodeScannerDialog({
    Key? key,
    required this.onBarcodeDetected
  }) : super(key: key);

  @override
  _BarcodeScannerDialogState createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        height: 400,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Scan Barcode',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange.shade700,
                ),
              ),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final barcode = barcodes.first.rawValue;
                    if (barcode != null) {
                      widget.onBarcodeDetected(barcode);
                    }
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                ),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}