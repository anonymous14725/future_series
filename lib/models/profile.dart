class Profile {
  Profile({
    required this.id,
    required this.username,
    required this.createdAt,
    this.phoneNumber,
    this.bio,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final DateTime createdAt;
  final String? phoneNumber;
  final String? bio; // تعریف فیلد جدید
  final String? avatarUrl;

  Profile.fromMap(Map<String, dynamic> map)
      : id = map['id'],
        username = map['username'],
        createdAt = DateTime.parse(map['created_at']),
        phoneNumber = map['phone_number'],
        bio = map['bio'],
        avatarUrl = map['avatar_url'];

  // به‌روزرسانی متد copyWith برای پشتیبانی از بیوگرافی
  Profile copyWith({
    String? id,
    String? username,
    DateTime? createdAt,
    String? phoneNumber,
    String? bio,
    String? avatarUrl,
  }) {
    return Profile(
      id: id ?? this.id,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}