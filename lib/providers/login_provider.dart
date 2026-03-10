import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'connection_provider.dart';
import 'game_state_provider.dart';

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

/// Provides the list of remembered characters with passwords, loaded from disk.
final savedAltsProvider = FutureProvider<List<SavedAlt>>((ref) async {
  final file = await _altsFile();
  if (!file.existsSync()) return [];
  try {
    final json = jsonDecode(await file.readAsString());
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
  } catch (_) {
    return [];
  }
});

Future<File> _altsFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/AncientAnguishClient/alts.json');
}

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

  Future<void> _saveAlt(String name, String password) async {
    final file = await _altsFile();
    List<SavedAlt> alts = [];
    if (file.existsSync()) {
      try {
        final json = jsonDecode(await file.readAsString()) as List;
        if (json.isNotEmpty && json.first is String) {
          alts = json.cast<String>().map((s) => SavedAlt(name: s, password: '')).toList();
        } else {
          alts = json.cast<Map<String, dynamic>>().map(SavedAlt.fromJson).toList();
        }
      } catch (_) {}
    }
    // Upsert: update password if name exists, else insert at front.
    final index = alts.indexWhere((a) => a.name == name);
    if (index >= 0) {
      alts[index] = SavedAlt(name: name, password: password);
    } else {
      alts.insert(0, SavedAlt(name: name, password: password));
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(alts.map((a) => a.toJson()).toList()));
    ref.invalidate(savedAltsProvider);
  }

  Future<void> _removeAlt(String name) async {
    final file = await _altsFile();
    if (!file.existsSync()) return;
    List<SavedAlt> alts = [];
    try {
      final json = jsonDecode(await file.readAsString()) as List;
      if (json.isNotEmpty && json.first is String) {
        alts = json.cast<String>().map((s) => SavedAlt(name: s, password: '')).toList();
      } else {
        alts = json.cast<Map<String, dynamic>>().map(SavedAlt.fromJson).toList();
      }
    } catch (_) {
      return;
    }
    alts.removeWhere((a) => a.name == name);
    await file.writeAsString(jsonEncode(alts.map((a) => a.toJson()).toList()));
    ref.invalidate(savedAltsProvider);
  }
}
