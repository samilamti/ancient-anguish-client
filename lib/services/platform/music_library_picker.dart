import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One picked track exported to the app's documents directory and ready
/// to be fed into the existing file-path-based audio pipeline.
class PickedMusicTrack {
  final String path;
  final String title;
  final String artist;
  final String persistentId;

  const PickedMusicTrack({
    required this.path,
    required this.title,
    required this.artist,
    required this.persistentId,
  });
}

/// A track the picker couldn't export (typically DRM-protected Apple Music
/// subscription items). Surfaced so the UI can show a snackbar instead of
/// silently dropping the user's selection.
class SkippedMusicTrack {
  final String title;
  final String artist;
  final String reason;

  const SkippedMusicTrack({
    required this.title,
    required this.artist,
    required this.reason,
  });
}

class MusicLibraryPickResult {
  final List<PickedMusicTrack> tracks;
  final List<SkippedMusicTrack> skipped;

  const MusicLibraryPickResult({
    required this.tracks,
    required this.skipped,
  });
}

/// True when the host is iOS — the only platform where the native Music
/// library picker is currently wired. Android equivalents (MediaStore) are
/// future work.
bool get isMusicLibraryHost =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

const _channel =
    MethodChannel('ancient_anguish_client/music_library');

/// Opens the native music library picker, exports the user's selection to
/// the app's documents directory, and returns both the successfully-
/// exported tracks and the ones the platform refused to hand over (DRM
/// etc.). Returns an empty result when the user cancels.
///
/// Only call when [isMusicLibraryHost] is true; on other platforms this
/// will throw a [MissingPluginException].
Future<MusicLibraryPickResult> pickFromMusicLibrary() async {
  final raw = await _channel.invokeMethod<dynamic>('pick');
  if (raw is! Map) {
    return const MusicLibraryPickResult(tracks: [], skipped: []);
  }
  final tracksRaw = raw['tracks'];
  final skippedRaw = raw['skipped'];
  final tracks = <PickedMusicTrack>[];
  if (tracksRaw is List) {
    for (final t in tracksRaw) {
      if (t is! Map) continue;
      final path = t['path'];
      if (path is! String || path.isEmpty) continue;
      tracks.add(PickedMusicTrack(
        path: path,
        title: (t['title'] as String?) ?? 'Unknown',
        artist: (t['artist'] as String?) ?? '',
        persistentId: (t['persistentId'] as String?) ?? '',
      ));
    }
  }
  final skipped = <SkippedMusicTrack>[];
  if (skippedRaw is List) {
    for (final s in skippedRaw) {
      if (s is! Map) continue;
      skipped.add(SkippedMusicTrack(
        title: (s['title'] as String?) ?? 'Unknown',
        artist: (s['artist'] as String?) ?? '',
        reason: (s['reason'] as String?) ?? 'unknown',
      ));
    }
  }
  return MusicLibraryPickResult(tracks: tracks, skipped: skipped);
}
