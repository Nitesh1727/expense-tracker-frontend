class User {
  final String id;
  final String? phone;
  final String? email;
  final String? name;
  final String? avatar;
  final String currency;
  final bool emailVerified;
  final bool monthlyReportEnabled;

  User({
    required this.id,
    this.phone,
    this.email,
    this.name,
    this.avatar,
    required this.currency,
    this.emailVerified = false,
    this.monthlyReportEnabled = true,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['_id'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        name: json['name'] as String?,
        avatar: json['avatar'] as String?,
        currency: json['currency'] as String? ?? 'INR',
        emailVerified: json['emailVerified'] as bool? ?? false,
        monthlyReportEnabled: json['monthlyReportEnabled'] as bool? ?? true,
      );
}
