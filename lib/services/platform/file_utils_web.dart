import 'package:flutter/widgets.dart';

/// Always returns `false` on web — local file paths are not accessible.
bool fileExistsSync(String path) => false;

/// Returns an empty widget on web — local file images are not supported.
Widget buildFileImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
  Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
}) {
  return const SizedBox.shrink();
}
