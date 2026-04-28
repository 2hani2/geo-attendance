class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'admin' or 'user'
  final String deviceId;
  final String assignedLocation;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.deviceId,
    required this.assignedLocation,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'user',
      deviceId: map['deviceId'] ?? '',
      assignedLocation: map['assignedLocation'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'deviceId': deviceId,
      'assignedLocation': assignedLocation,
    };
  }
}