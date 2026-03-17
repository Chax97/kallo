class Contact {
  final String id;
  final String name;
  final String? phoneNumber;
  final String? mobileNumber;
  final String? companyName;
  final String? phoneBook;
  final String? email;
  final DateTime? createdAt;

  const Contact({
    required this.id,
    required this.name,
    this.phoneNumber,
    this.mobileNumber,
    this.companyName,
    this.phoneBook,
    this.email,
    this.createdAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as String,
        name: json['name'] as String,
        phoneNumber: json['phone_number'] as String?,
        mobileNumber: json['mobile_number'] as String?,
        companyName: json['company_name'] as String?,
        phoneBook: json['phone_book'] as String?,
        email: json['email'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
