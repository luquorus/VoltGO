import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token storage abstraction
/// 
/// Mobile: Uses flutter_secure_storage (encrypted keychain/keystore)
/// Web: Uses shared_preferences (localStorage)
/// 
/// SECURITY NOTE for Web:
/// shared_preferences uses localStorage which is accessible to JavaScript.
/// For production, consider using httpOnly cookies or a more secure storage mechanism.
/// This is a tradeoff for simplicity in Flutter Web.
class TokenStorage {
  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyEmail = 'auth_email';
  static const String _keyRole = 'auth_role';

  final FlutterSecureStorage? _secureStorage;
  final SharedPreferences? _prefs;

  TokenStorage()
      : _secureStorage = kIsWeb ? null : const FlutterSecureStorage(),
        _prefs = null {
    // Initialize SharedPreferences for web
    if (kIsWeb) {
      SharedPreferences.getInstance().then((prefs) {
        // Store in instance variable would require async initialization
        // For now, we'll get it on-demand
      });
    }
  }

  // Web: Use SharedPreferences (localStorage)
  // Mobile: Use FlutterSecureStorage (encrypted)
  Future<String?> getToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyToken);
    } else {
      return await _secureStorage?.read(key: _keyToken);
    }
  }

  Future<String?> getUserId() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserId);
    } else {
      return await _secureStorage?.read(key: _keyUserId);
    }
  }

  Future<String?> getEmail() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyEmail);
    } else {
      return await _secureStorage?.read(key: _keyEmail);
    }
  }

  Future<String?> getRole() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyRole);
    } else {
      return await _secureStorage?.read(key: _keyRole);
    }
  }

  Future<void> saveToken(String token) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
    } else {
      await _secureStorage?.write(key: _keyToken, value: token);
    }
  }

  Future<void> saveUserId(String userId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserId, userId);
    } else {
      await _secureStorage?.write(key: _keyUserId, value: userId);
    }
  }

  Future<void> saveEmail(String email) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyEmail, email);
    } else {
      await _secureStorage?.write(key: _keyEmail, value: email);
    }
  }

  Future<void> saveRole(String role) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRole, role);
    } else {
      await _secureStorage?.write(key: _keyRole, value: role);
    }
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyRole);
    } else {
      await _secureStorage?.delete(key: _keyToken);
      await _secureStorage?.delete(key: _keyUserId);
      await _secureStorage?.delete(key: _keyEmail);
      await _secureStorage?.delete(key: _keyRole);
    }
  }
}

