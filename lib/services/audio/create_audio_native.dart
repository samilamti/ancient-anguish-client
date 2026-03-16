import 'audio_interface.dart';
import 'audio_service.dart';

/// Creates the desktop audio service (flutter_soloud FFI engine).
AudioInterface createAudioService({
  String? baseUrl,
  String Function()? tokenProvider,
}) {
  return NativeAudioService();
}
