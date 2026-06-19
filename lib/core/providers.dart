import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_storage.dart';

// Notifier para estado de autenticação global
class AuthState {
  final bool isLoggedIn;
  final String? role;
  final String? username;
  const AuthState({this.isLoggedIn = false, this.role, this.username});
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState();

  Future<void> load() async {
    final token = await AuthStorage.getToken();
    final role = await AuthStorage.getRole();
    final username = await AuthStorage.getUsername();
    state = AuthState(isLoggedIn: token != null, role: role, username: username);
  }

  void login(String username, String role) {
    state = AuthState(isLoggedIn: true, role: role, username: username);
  }

  Future<void> logout() async {
    await AuthStorage.clear();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
