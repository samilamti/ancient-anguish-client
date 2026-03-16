import 'dart:io';

import 'package:flutter/widgets.dart';

/// Checks whether a file exists at [path] synchronously (desktop only).
bool fileExistsSync(String path) => File(path).existsSync();

/// Builds an [Image] widget from a local file at [path] (desktop only).
Widget buildFileImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  return Image.file(
    File(path),
    fit: fit,
    width: width,
    height: height,
    errorBuilder: errorBuilder,
  );
}
