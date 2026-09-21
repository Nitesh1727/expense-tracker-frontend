import 'package:shared_preferences/shared_preferences.dart';
import '../domain/user.dart';

/// Local mode has no account, just the name + avatar the user picked, kept
/// on-device. The fixed id/currency make it a well-formed [User] so the
/// existing Profile UI works unchanged.
class LocalProfileStore {
  static const _nameKey = 'local_profile_name';
  static const _avatarKey = 'local_profile_avatar';

  static Future<User> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _build(prefs.getString(_nameKey), prefs.getString(_avatarKey));
  }

  /// Only the fields passed change, same as the cloud PATCH /auth/me.
  static Future<User> update({String? name, String? avatar}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString(_nameKey, name);
    if (avatar != null) await prefs.setString(_avatarKey, avatar);
    return _build(prefs.getString(_nameKey), prefs.getString(_avatarKey));
  }

  static Future<User> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_nameKey);
    await prefs.remove(_avatarKey);
    return _build(null, null);
  }

  static User _build(String? name, String? avatar) =>
      User(id: 'local', name: name, avatar: avatar, currency: 'INR', emailVerified: true, monthlyReportEnabled: false);
}
