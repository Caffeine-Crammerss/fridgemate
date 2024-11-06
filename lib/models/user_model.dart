class UserModel {
  String userId;
  String name;
  String email;
  Map<String, dynamic> preferences;

  UserModel({
    required this.userId,
    required this.name,
    required this.email,
    required this.preferences,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'name': name,
      'email': email,
      'preferences': preferences,
    };
  }

  UserModel.fromMap(Map<String, dynamic> map)
      : userId = map['user_id'],
        name = map['name'],
        email = map['email'],
        preferences = Map<String, dynamic>.from(map['preferences']);
}
