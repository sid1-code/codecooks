import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/token_service.dart';

class AuthState {
  final AppUser? user;
  final String? token;
  const AuthState({this.user, this.token});

  bool get isLoggedIn => user != null && token != null;
  bool get isAdmin => user?.isAdmin == true;

  AuthState copyWith({AppUser? user, String? token}) =>
      AuthState(user: user ?? this.user, token: token ?? this.token);
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._tokens) : super(const AuthState());

  final TokenService _tokens;

  Future<void> load() async {
    final tok = await _tokens.getToken();
    // If you have a persisted user profile, load here. For now, token only.
    state = state.copyWith(token: tok);
  }

  Future<void> login({required String token, required AppUser user}) async {
    await _tokens.saveToken(token);
    state = AuthState(user: user, token: token);
  }

  Future<void> logout() async {
    await _tokens.clearToken();
    state = const AuthState();
  }
}

final tokenServiceProvider = Provider<TokenService>((ref) => TokenService());
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final tok = ref.read(tokenServiceProvider);
  final notifier = AuthNotifier(tok);
  // lazily load token
  notifier.load();
  return notifier;
});
