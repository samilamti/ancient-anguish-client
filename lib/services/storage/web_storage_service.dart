import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import 'storage_service.dart';

/// Web implementation of [StorageService] that stores files on the server
/// via HTTP calls to the file API.
///
/// Each request includes a JWT Bearer token for authentication.
class WebStorageService implements StorageService {
  WebStorageService({
    required String baseUrl,
    required String Function() tokenProvider,
  })  : _baseUrl = baseUrl,
        _tokenProvider = tokenProvider;

  final String _baseUrl;
  final String Function() _tokenProvider;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${_tokenProvider()}',
      };

  String _fileUrl(String name) =>
      '$_baseUrl/api/files/${Uri.encodeComponent(name)}';

  @override
  Future<String> readFile(String name) async {
    try {
      final response = await http.get(
        Uri.parse(_fileUrl(name)),
        headers: _headers,
      );
      if (response.statusCode == 200) return response.body;
      return '';
    } catch (e) {
      debugPrint('WebStorageService.readFile($name): $e');
      return '';
    }
  }

  @override
  Future<List<String>> readFileLines(String name) async {
    try {
      final response = await http.get(
        Uri.parse('${_fileUrl(name)}/lines'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.cast<String>();
      }
      return [];
    } catch (e) {
      debugPrint('WebStorageService.readFileLines($name): $e');
      return [];
    }
  }

  @override
  Future<void> writeFile(String name, String contents) async {
    try {
      await http.put(
        Uri.parse(_fileUrl(name)),
        headers: {
          ..._headers,
          'Content-Type': 'text/plain',
        },
        body: contents,
      );
    } catch (e) {
      debugPrint('WebStorageService.writeFile($name): $e');
    }
  }

  @override
  Future<void> appendToFile(String name, String text) async {
    try {
      await http.post(
        Uri.parse('${_fileUrl(name)}/append'),
        headers: {
          ..._headers,
          'Content-Type': 'text/plain',
        },
        body: text,
      );
    } catch (e) {
      debugPrint('WebStorageService.appendToFile($name): $e');
    }
  }

  @override
  Future<bool> fileExists(String name) async {
    try {
      final response = await http.get(
        Uri.parse('${_fileUrl(name)}/meta'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return response.headers['x-file-exists'] == 'true';
      }
      return false;
    } catch (e) {
      debugPrint('WebStorageService.fileExists($name): $e');
      return false;
    }
  }

  @override
  Future<int> fileLength(String name) async {
    try {
      final response = await http.get(
        Uri.parse('${_fileUrl(name)}/meta'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final length = response.headers['x-file-length'];
        return length != null ? int.tryParse(length) ?? 0 : 0;
      }
      return 0;
    } catch (e) {
      debugPrint('WebStorageService.fileLength($name): $e');
      return 0;
    }
  }

  @override
  Future<void> ensureFile(String name, [String defaultContents = '']) async {
    try {
      await http.post(
        Uri.parse('${_fileUrl(name)}/ensure'),
        headers: {
          ..._headers,
          'Content-Type': 'text/plain',
        },
        body: defaultContents,
      );
    } catch (e) {
      debugPrint('WebStorageService.ensureFile($name): $e');
    }
  }

  @override
  Future<void> ensureDirectories() async {
    // No-op on web — server manages directories.
  }
}
