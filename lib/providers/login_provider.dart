import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage/storage_service.dart';
import 'alias_provider.dart';
import 'connection_provider.dart';
import 'game_state_provider.dart';
import 'storage_provider.dart';

// ── Login state ──

/// Represents the current phase of the login flow.
sealed class LoginState {
  const LoginState();
}

/// No login dialog visible.
class LoginIdle extends LoginState {
  const LoginIdle();
}

/// "What is your name:" detected – dialog is shown.
class LoginPromptDetected extends LoginState {
  const LoginPromptDetected();
}

/// Credentials submitted – dialog dismissed.
class LoginComplete extends LoginState {
  const LoginComplete();
}

// ── Saved alts ──

/// A remembered character with name and password.
class SavedAlt {
  final String name;
  final String password;
  const SavedAlt({required this.name, required this.password});

  Map<String, dynamic> toJson() => {'name': name, 'password': password};

  factory SavedAlt.fromJson(Map<String, dynamic> json) => SavedAlt(
        name: json['name'] as String,
        password: json['password'] as String? ?? '',
      );
}

const _altsFileName = 'alts.json';

/// Provides the list of remembered characters with passwords, loaded from disk.
final savedAltsProvider = FutureProvider<List<SavedAlt>>((ref) async {
  final storage = ref.read(storageServiceProvider);
  final contents = await storage.readFile(_altsFileName);
  if (contents.trim().isEmpty) return [];
  try {
    final json = jsonDecode(contents);
    final list = json as List;
    if (list.isEmpty) return [];
    // Backwards compatibility: old format was ["Name1", "Name2"].
    if (list.first is String) {
      return list.cast<String>().map((s) => SavedAlt(name: s, password: '')).toList();
    }
    return list
        .cast<Map<String, dynamic>>()
        .map(SavedAlt.fromJson)
        .toList();
  } catch (e) {
    debugPrint('savedAltsProvider: parse error: $e');
    return [];
  }
});

// ── Login notifier ──

/// Manages the login dialog lifecycle and credential submission.
final loginProvider =
    NotifierProvider<LoginNotifier, LoginState>(LoginNotifier.new);

class LoginNotifier extends Notifier<LoginState> {
  String? _pendingPassword;

  @override
  LoginState build() => const LoginIdle();

  /// Called when "What is your name:" is detected in MUD output.
  void onNamePromptDetected() {
    if (state is LoginIdle) {
      state = const LoginPromptDetected();
    }
  }

  /// User clicked Login with a character name and password.
  void submitCredentials(String name, String password, bool remember) {
    final service = ref.read(connectionServiceProvider);
    service.sendCommand(name);
    _pendingPassword = password;
    // Store character name for title bar display.
    ref.read(gameStateProvider.notifier).setPlayerName(
      name[0].toUpperCase() + name.substring(1).toLowerCase(),
    );
    state = const LoginComplete();

    if (remember) {
      _saveAlt(name, password);
    }
  }

  /// User clicked Guest.
  void submitGuest() {
    final service = ref.read(connectionServiceProvider);
    service.sendCommand('guest');
    _pendingPassword = null;
    state = const LoginComplete();
  }

  /// Called when "Password:" is detected and we have a pending password.
  ///
  /// Sends the password, then triggers post-login actions.
  void onPasswordPromptDetected() {
    if (_pendingPassword == null) return;
    final service = ref.read(connectionServiceProvider);
    service.sendCommand(_pendingPassword!);
    _pendingPassword = null;
    _performPostLogin();
  }

  /// Sets `_loginDetected` and sends the prompt command.
  void _performPostLogin() {
    final bufferNotifier = ref.read(terminalBufferProvider.notifier);
    bufferNotifier.setLoginDetected();
    final service = ref.read(connectionServiceProvider);
    service.sendCommand(
      'prompt set @@|HP| |MAXHP| |SP| |MAXSP| |XCOORD| |YCOORD|@@',
    );
    // Force alias loading from disk (provider is lazy, only loads on first access).
    ref.read(aliasRulesProvider);
  }

  /// User dismissed the dialog to type manually.
  void dismiss() {
    _pendingPassword = null;
    state = const LoginIdle();
  }

  /// Reset on disconnect.
  void reset() {
    _pendingPassword = null;
    state = const LoginIdle();
  }

  // ── Alt persistence ──

  /// Removes a saved character.
  Future<void> removeAlt(String name) async {
    await _removeAlt(name);
  }

  StorageService get _storage => ref.read(storageServiceProvider);

  Future<List<SavedAlt>> _readAlts() async {
    final contents = await _storage.readFile(_altsFileName);
    if (contents.trim().isEmpty) return [];
    try {
      final json = jsonDecode(contents) as List;
      if (json.isEmpty) return [];
      if (json.first is String) {
        return json.cast<String>().map((s) => SavedAlt(name: s, password: '')).toList();
      }
      return json.cast<Map<String, dynamic>>().map(SavedAlt.fromJson).toList();
    } catch (e) {
      debugPrint('LoginNotifier._readAlts: parse error: $e');
      return [];
    }
  }

  Future<void> _writeAlts(List<SavedAlt> alts) async {
    await _storage.writeFile(
      _altsFileName,
      jsonEncode(alts.map((a) => a.toJson()).toList()),
    );
    ref.invalidate(savedAltsProvider);
  }

  Future<void> _saveAlt(String name, String password) async {
    final alts = await _readAlts();
    // Upsert: update password if name exists, else insert at front.
    final index = alts.indexWhere((a) => a.name == name);
    if (index >= 0) {
      alts[index] = SavedAlt(name: name, password: password);
    } else {
      alts.insert(0, SavedAlt(name: name, password: password));
    }
    await _writeAlts(alts);
  }

  Future<void> _removeAlt(String name) async {
    final alts = await _readAlts();
    if (alts.isEmpty) return;
    alts.removeWhere((a) => a.name == name);
    await _writeAlts(alts);
  }
}
