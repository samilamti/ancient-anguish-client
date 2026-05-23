import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// True when the host is an iOS or Android device. Used to gate use of
/// the Photos / Gallery picker (which only ships on those platforms);
/// desktop and web keep the existing file-picker path.
bool get isPhotoLibraryHost =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);

/// Picks a single image from the device's photo library (iOS Photos,
/// Android Photo Picker) and copies it into the app's documents
/// directory so the saved path survives across launches and OS cache
/// eviction. Returns the persistent absolute path of the copy, or null
/// if the user cancelled.
///
/// [subdir] keeps callers from colliding — Area backgrounds, future
/// avatar uploads, etc. can each request their own folder.
Future<String?> pickFromPhotoLibrary({String subdir = 'photos'}) async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null) return null;

  final docs = await getApplicationDocumentsDirectory();
  final targetDir = Directory('${docs.path}/$subdir');
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  final stamp = DateTime.now().millisecondsSinceEpoch;
  final safeName = picked.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final dest = File('${targetDir.path}/${stamp}_$safeName');
  await File(picked.path).copy(dest.path);
  return dest.path;
}
