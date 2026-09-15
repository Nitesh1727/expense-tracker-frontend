class User {
  final String id;
  final String? phone;
  final String? email;
  final String? name;
  final String currency;

  User({required this.id, this.phone, this.email, this.name, required this.currency});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['_id'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        name: json['name'] as String?,
        currency: json['currency'] as String? ?? 'INR',
      );
}
