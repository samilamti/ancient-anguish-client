import 'audio_interface.dart';
import 'web_audio_service.dart';

/// Creates the web audio service (HTML5 Audio API).
AudioInterface createAudioService({
  String? baseUrl,
  String Function()? tokenProvider,
}) {
  assert(baseUrl != null, 'baseUrl required for web audio service');
  assert(tokenProvider != null, 'tokenProvider required for web audio service');
  return WebAudioService(
    baseUrl: baseUrl!,
    tokenProvider: tokenProvider!,
  );
}
