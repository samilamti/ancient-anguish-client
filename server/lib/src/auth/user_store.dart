import 'dart:convert';
import 'dart:io';

import 'package:dbcrypt/dbcrypt.dart';

/// Manages user accounts persisted to a JSON file.
///
/// File format: `{"users": [{"username": "...", "passwordHash": "...", "created": "..."}]}`
class UserStore {
  final String dataDir;
  final List<Map<String, dynamic>> _users = [];
  bool _loaded = false;

  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,30}$');
  static const _minPasswordLength = 8;
  static const _bcryptCost = 10;

  UserStore(this.dataDir);

  String get _filePath => '$dataDir/users.json';

  /// Loads users from disk. Safe to call multiple times.
  Future<void> load() async {
    if (_loaded) return;
    final file = File(_filePath);
    if (await file.exists()) {
      try {
        final contents = await file.readAsString();
        final data = jsonDecode(contents) as Map<String, dynamic>;
        final list = data['users'] as List<dynamic>? ?? [];
        _users.clear();
        for (final entry in list) {
          _users.add(Map<String, dynamic>.from(entry as Map));
        }
      } catch (e) {
        // Corrupted file — start fresh.
        _users.clear();
      }
    }
    _loaded = true;
  }

  /// Registers a new user. Returns `null` on success, or an error message.
  Future<String?> register(String username, String password) async {
    await load();

    if (!_usernameRegex.hasMatch(username)) {
      return 'Username must be 3-30 alphanumeric characters or underscores.';
    }
    if (password.length < _minPasswordLength) {
      return 'Password must be at least $_minPasswordLength characters.';
    }
    if (_users.any(
        (u) => (u['username'] as String).toLowerCase() == username.toLowerCase())) {
      return 'Username already taken.';
    }

    final hash = DBCrypt().hashpw(password, DBCrypt().gensaltWithRounds(_bcryptCost));

    _users.add({
      'username': username,
      'passwordHash': hash,
      'created': DateTime.now().toUtc().toIso8601String(),
    });

    await _save();
    return null;
  }

  /// Authenticates a user. Returns the username (canonical case) or `null`.
  Future<String?> authenticate(String username, String password) async {
    await load();

    final user = _users.cast<Map<String, dynamic>?>().firstWhere(
      (u) => (u!['username'] as String).toLowerCase() == username.toLowerCase(),
      orElse: () => null,
    );
    if (user == null) return null;

    final hash = user['passwordHash'] as String;
    if (DBCrypt().checkpw(password, hash)) {
      return user['username'] as String;
    }
    return null;
  }

  /// Whether a username is already registered (case-insensitive).
  bool userExists(String username) {
    return _users.any(
        (u) => (u['username'] as String).toLowerCase() == username.toLowerCase());
  }

  Future<void> _save() async {
    final file = File(_filePath);
    await file.parent.create(recursive: true);
    final json = jsonEncode({'users': _users});
    await file.writeAsString(json);
  }
}
