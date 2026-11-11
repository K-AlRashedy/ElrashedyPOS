import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The device token lives in the OS credential store (DPAPI on Windows),
/// never in the plain SQLite file.
class SecureStore {
  SecureStore()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          wOptions: WindowsOptions(),
        );

  final FlutterSecureStorage _storage;
  static const _tokenKey = 'elrashedy_pos_device_token';

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<void> writeToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);
}