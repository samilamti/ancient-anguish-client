import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/platform/file_utils.dart';
import '../../providers/audio_provider.dart';
import '../../providers/background_image_provider.dart';
import '../../providers/game_state_provider.dart';
import '../../providers/unified_area_config_provider.dart';
import '../widgets/common/escape_dismiss.dart';

/// Unified screen for managing per-area music, background images, and battle themes.
class AreaConfigurationScreen extends ConsumerStatefulWidget {
  const AreaConfigurationScreen({super.key});

  @override
  ConsumerState<AreaConfigurationScreen> createState() =>
      _AreaConfigurationScreenState();
}

class _AreaConfigurationScreenState
    extends ConsumerState<AreaConfigurationScreen> {
  String? _selectedArea;

  @override
  Widget build(BuildContext context) {
    final areaDetector = ref.watch(areaDetectorProvider).value;
    final unifiedConfig = ref.watch(unifiedAreaConfigProvider).value;
    final audioState = ref.watch(audioUiStateProvider);
    final audioNotifier = ref.read(audioUiStateProvider.notifier);
    final battleThemes = audioState.battleThemes;
    final theme = Theme.of(context);

    // Merge area names from detector and existing config.
    final areaSet = <String>{};
    if (areaDetector != null) {
      areaSet.addAll(areaDetector.areas.map((a) => a.name));
    }
    if (unifiedConfig != null) {
      areaSet.addAll(unifiedConfig.areaNames);
    }
    final areas = areaSet.toList()..sort();

    // Ensure selected area is still valid.
    if (_selectedArea != null && !areas.contains(_selectedArea)) {
      _selectedArea = null;
    }

    // Data for selected area.
    final musicTracks = _selectedArea != null
        ? (unifiedConfig?.getMusicListForArea(_selectedArea!) ?? const [])
        : const <String>[];
    final backgrounds = _selectedArea != null
        ? (unifiedConfig?.getBackgroundsForArea(_selectedArea!) ?? const [])
        : const <String>[];

    return EscapeDismiss(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Area Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help',
            onPressed: () => _showHelp(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Area selector ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.map, color: theme.colorScheme.primary,
                          size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Select Area',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose an area to configure its music and background images.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedArea,
                    decoration: const InputDecoration(
                      labelText: 'Area',
                      hintText: 'Select an area',
                    ),
                    items: areas.map((area) {
                      return DropdownMenuItem(
                        value: area,
                        child: Text(area),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedArea = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Music tracks for selected area ──
          if (_selectedArea != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.music_note,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Music Tracks',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (musicTracks.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No music assigned to $_selectedArea.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withAlpha(100),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ...musicTracks.map((path) {
                        final fileName =
                            path.split('/').last.split('\\').last;
                        final fileExists = fileExistsSync(path);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            fileExists
                                ? Icons.music_note
                                : Icons.error_outline,
                            size: 20,
                            color: fileExists
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                          ),
                          title: Text(
                            fileName,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 12,
                              color: fileExists
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.error,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: theme.colorScheme.error,
                            onPressed: () {
                              unifiedConfig?.removeMusicFromArea(
                                  _selectedArea!, path);
                              // Reload audio manager's track map.
                              final manager =
                                  ref.read(areaAudioManagerProvider);
                              manager.removeTrackForArea(_selectedArea!);
                              if (unifiedConfig != null) {
                                manager.loadUserTrackMap(
                                    unifiedConfig.userTrackMap);
                              }
                              setState(() {});
                            },
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    if (!kIsWeb)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Track'),
                          onPressed: () => _pickAndAddMusic(unifiedConfig),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Background images for selected area ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.image,
                            color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Background Images',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (backgrounds.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No background images assigned to $_selectedArea.',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withAlpha(100),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      )
                    else
                      ...backgrounds.map((path) {
                        final fileName =
                            path.split('/').last.split('\\').last;
                        final fileExists = fileExistsSync(path);
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: fileExists
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: buildFileImage(
                                    path,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Icon(Icons.error_outline, size: 20,
                                  color: theme.colorScheme.error),
                          title: Text(
                            fileName,
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontSize: 12,
                              color: fileExists
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.error,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: theme.colorScheme.error,
                            onPressed: () {
                              unifiedConfig?.removeBackgroundFromArea(
                                  _selectedArea!, path);
                              ref.invalidate(backgroundImageProvider);
                              setState(() {});
                            },
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    if (!kIsWeb)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Image'),
                          onPressed: () => _pickAndAddImage(unifiedConfig),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Battle Themes section ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Battle Themes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add MP3 files to play during combat. Each new battle '
                    'plays the next track in the list, cycling back to the first.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!kIsWeb)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Battle Theme'),
                        onPressed: () => _pickBattleTheme(audioNotifier),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (battleThemes.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No battle themes added.\n'
                    'Add MP3 files to hear music during combat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(100),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            )
          else
            ...List.generate(battleThemes.length, (index) {
              final path = battleThemes[index];
              final fileName = path.split('/').last.split('\\').last;
              final fileExists = fileExistsSync(path);

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primary.withAlpha(30),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  title: Text(fileName),
                  subtitle: !fileExists
                      ? Text(
                          'File not found',
                          style: TextStyle(color: theme.colorScheme.error),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 20),
                          tooltip: 'Move up',
                          onPressed: () {
                            audioNotifier.reorderBattleThemes(
                                index, index - 1);
                          },
                        ),
                      if (index < battleThemes.length - 1)
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 20),
                          tooltip: 'Move down',
                          onPressed: () {
                            audioNotifier.reorderBattleThemes(
                                index, index + 2);
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: theme.colorScheme.error,
                        onPressed: () {
                          audioNotifier.removeBattleThemeAt(index);
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    ),
    );
  }

  Future<void> _pickAndAddMusic(dynamic unifiedConfig) async {
    if (_selectedArea == null || unifiedConfig == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      allowMultiple: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      if (file.path == null) continue;
      if (!fileExistsSync(file.path!)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File not found: ${file.path}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        continue;
      }
      unifiedConfig.addMusicForArea(_selectedArea!, file.path!);
    }
    // Reload audio manager's track map.
    final manager = ref.read(areaAudioManagerProvider);
    manager.loadUserTrackMap(unifiedConfig.userTrackMap);
    setState(() {});
  }

  Future<void> _pickAndAddImage(dynamic unifiedConfig) async {
    if (_selectedArea == null || unifiedConfig == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    if (!fileExistsSync(path)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File not found: $path'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }
    unifiedConfig.addBackgroundForArea(_selectedArea!, path);
    ref.invalidate(backgroundImageProvider);
    setState(() {});
  }

  Future<void> _pickBattleTheme(AudioUiNotifier notifier) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
      allowMultiple: true,
    );
    if (result == null) return;
    for (final file in result.files) {
      if (file.path == null) continue;
      if (!fileExistsSync(file.path!)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File not found: ${file.path}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        continue;
      }
      notifier.addBattleTheme(file.path!);
    }
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Area Configuration Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Music Tracks:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '1. Select an area, then add MP3 files.\n'
                '2. When your character enters the area, the track plays '
                'automatically with crossfading.\n'
                '3. Areas with multiple tracks play them in sequence.\n'
                '4. Areas with no tracks fade to silence.',
              ),
              SizedBox(height: 16),
              Text(
                'Background Images:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '1. Assign PNG or JPEG images to areas.\n'
                '2. The image is displayed behind the terminal text at low '
                'opacity so text remains readable.\n'
                '3. Areas with multiple images cycle through them.',
              ),
              SizedBox(height: 16),
              Text(
                'Battle Themes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '1. Add MP3 files to the Battle Themes list.\n'
                '2. When combat is detected, the next track in the list plays.\n'
                '3. Each new battle advances to the next track, cycling back.\n'
                '4. When combat ends, area audio resumes automatically.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
