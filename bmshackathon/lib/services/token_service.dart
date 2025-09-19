import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenService {
  static const _kJwt = 'auth_jwt_token';
  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> saveToken(String jwt) async {
    await _secure.write(key: _kJwt, value: jwt);
  }

  Future<String?> getToken() async {
    return _secure.read(key: _kJwt);
  }

  Future<void> clearToken() async {
    await _secure.delete(key: _kJwt);
  }
}
