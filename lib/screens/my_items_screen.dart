import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../globals.dart'; // Import globals to access `itemList` and `categories`
import 'add_item_screen.dart'; // Adjust the path if necessary

class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({Key? key}) : super(key: key);

  @override
  _MyItemsScreenState createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  void _deleteItem(Map<String, dynamic> item) {
    setState(() {
      itemList.remove(item);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Item deleted')),
    );
  }

  void _editItem(Map<String, dynamic> item, int index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddSingleItemDialog(item: item),
    );

    if (result != null) {
      setState(() {
        itemList[index] = result; // Update the item in the global list
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item updated successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // Filter items by category
            final itemsInCategory = itemList.where((item) {
              return item['category'] == category;
            }).toList();

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
                final globalIndex = itemList.indexOf(item); // Get global index
                final expiryDate = item['expiryDate'] ??
                    DateTime.now().add(const Duration(days: 7)); // Default expiry date
                final expired = expiryDate.isBefore(DateTime.now());

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              item['name'] ?? "Unnamed Item",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () {
                                    _editItem(item, globalIndex);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    _deleteItem(item);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Expiry Date: ${DateFormat('MM/dd/yyyy').format(expiryDate)}",
                        ),
                        if (expired)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              "Expired ${DateTime.now().difference(expiryDate).inDays} days ago",
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
