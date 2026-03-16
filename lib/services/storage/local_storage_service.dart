import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

import 'storage_service.dart';

/// Desktop [StorageService] implementation using `dart:io` and `path_provider`.
///
/// Resolves logical file names to `{appDocuments}/AncientAnguishClient/{name}`.
class LocalStorageService extends StorageService {
  String? _basePath;

  /// Returns the base directory path, initializing it lazily.
  Future<String> get basePath async {
    if (_basePath != null) return _basePath!;
    final dir = await getApplicationDocumentsDirectory();
    _basePath = '${dir.path}/AncientAnguishClient';
    return _basePath!;
  }

  File _resolve(String base, String name) => File('$base/$name');

  @override
  Future<String> readFile(String name) async {
    try {
      final file = _resolve(await basePath, name);
      if (!file.existsSync()) return '';
      return await file.readAsString();
    } catch (e) {
      debugPrint('LocalStorageService.readFile($name): $e');
      return '';
    }
  }

  @override
  Future<List<String>> readFileLines(String name) async {
    try {
      final file = _resolve(await basePath, name);
      if (!file.existsSync()) return [];
      return await file.readAsLines();
    } catch (e) {
      debugPrint('LocalStorageService.readFileLines($name): $e');
      return [];
    }
  }

  @override
  Future<void> writeFile(String name, String contents) async {
    try {
      final file = _resolve(await basePath, name);
      await file.parent.create(recursive: true);
      await file.writeAsString(contents);
    } catch (e) {
      debugPrint('LocalStorageService.writeFile($name): $e');
    }
  }

  @override
  Future<void> appendToFile(String name, String text) async {
    try {
      final file = _resolve(await basePath, name);
      await file.parent.create(recursive: true);
      await file.writeAsString(text, mode: FileMode.append);
    } catch (e) {
      debugPrint('LocalStorageService.appendToFile($name): $e');
    }
  }

  @override
  Future<bool> fileExists(String name) async {
    try {
      final file = _resolve(await basePath, name);
      return file.existsSync();
    } catch (e) {
      debugPrint('LocalStorageService.fileExists($name): $e');
      return false;
    }
  }

  @override
  Future<int> fileLength(String name) async {
    try {
      final file = _resolve(await basePath, name);
      if (!file.existsSync()) return 0;
      return await file.length();
    } catch (e) {
      debugPrint('LocalStorageService.fileLength($name): $e');
      return 0;
    }
  }

  @override
  Future<void> ensureFile(String name, [String defaultContents = '']) async {
    try {
      final file = _resolve(await basePath, name);
      if (!file.existsSync()) {
        await file.parent.create(recursive: true);
        await file.writeAsString(defaultContents);
      }
    } catch (e) {
      debugPrint('LocalStorageService.ensureFile($name): $e');
    }
  }

  @override
  Future<void> ensureDirectories() async {
    try {
      await Directory(await basePath).create(recursive: true);
    } catch (e) {
      debugPrint('LocalStorageService.ensureDirectories: $e');
    }
  }
}
