class InventoryItem {
  String itemId;
  String itemName;
  int quantity;
  DateTime expirationDate;
  String userId;

  InventoryItem({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.expirationDate,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'item_id': itemId,
      'item_name': itemName,
      'quantity': quantity,
      'expiration_date': expirationDate.toIso8601String(),
      'user_id': userId,
    };
  }

  InventoryItem.fromMap(Map<String, dynamic> map)
      : itemId = map['item_id'],
        itemName = map['item_name'],
        quantity = map['quantity'],
        expirationDate = DateTime.parse(map['expiration_date']),
        userId = map['user_id'];
}
