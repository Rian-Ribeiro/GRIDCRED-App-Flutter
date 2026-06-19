import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class AuthStorage {
  static const _s = FlutterSecureStorage();

  static Future<void> saveToken(String token) => _s.write(key: kTokenKey, value: token);
  static Future<String?> getToken() => _s.read(key: kTokenKey);
  static Future<void> deleteToken() => _s.delete(key: kTokenKey);

  static Future<void> saveBaseUrl(String url) => _s.write(key: kBaseUrlKey, value: url);
  static Future<String> getBaseUrl() async => await _s.read(key: kBaseUrlKey) ?? kDefaultBaseUrl;

  static Future<void> saveUser(String username, String role) async {
    await _s.write(key: kUsernameKey, value: username);
    await _s.write(key: kRoleKey, value: role);
  }
  static Future<String?> getUsername() => _s.read(key: kUsernameKey);
  static Future<String?> getRole() => _s.read(key: kRoleKey);

  static Future<void> clear() async {
    await _s.delete(key: kTokenKey);
    await _s.delete(key: kUsernameKey);
    await _s.delete(key: kRoleKey);
  }
}
