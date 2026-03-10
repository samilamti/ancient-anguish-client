import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/audio_provider.dart';
import '../../providers/game_state_provider.dart';

/// Screen for managing area-to-MP3 track mappings.
///
/// Users can assign their own MP3 files to each detected area.
/// Tracks are stored as absolute file paths.
class AudioSettingsScreen extends ConsumerStatefulWidget {
  const AudioSettingsScreen({super.key});

  @override
  ConsumerState<AudioSettingsScreen> createState() =>
      _AudioSettingsScreenState();
}

class _AudioSettingsScreenState extends ConsumerState<AudioSettingsScreen> {
  String? _selectedFilePath;
  String? _selectedArea;

  @override
  Widget build(BuildContext context) {
    final areaDetector = ref.watch(areaDetectorProvider).value;
    final audioNotifier = ref.read(audioUiStateProvider.notifier);
    final audioManager = ref.read(areaAudioManagerProvider);
    final userTracks = audioManager.userTrackMap;
    final theme = Theme.of(context);

    final areas =
        areaDetector?.areas.map((a) => a.name).toList() ?? <String>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Settings'),
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
          // Instructions.
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
                        'Area Soundtracks',
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
                    'Assign MP3 files to game areas. When you enter an area, '
                    'the assigned track will play automatically with crossfading.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Add new mapping.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Track Mapping',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Area dropdown.
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
                  const SizedBox(height: 12),

                  // File picker.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedFilePath != null
                              ? _selectedFilePath!
                                    .split('/')
                                    .last
                                    .split('\\')
                                    .last
                              : 'No file selected',
                          style: TextStyle(
                            color: _selectedFilePath != null
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withAlpha(100),
                            fontStyle: _selectedFilePath != null
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedFilePath != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _selectedFilePath = null),
                        ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Browse...'),
                        onPressed: _pickFile,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Add button.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Assign Track'),
                      onPressed: _selectedArea != null &&
                              _selectedFilePath != null
                          ? () => _addMapping(audioNotifier)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Current mappings.
          Text(
            'Current Mappings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          if (userTracks.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No track mappings yet.\nAssign MP3 files to areas above.',
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
            ...userTracks.entries.map((entry) {
              final fileName = entry.value.split('/').last.split('\\').last;
              final fileExists = File(entry.value).existsSync();

              return Card(
                child: ListTile(
                  leading: Icon(
                    fileExists ? Icons.music_note : Icons.error_outline,
                    color: fileExists
                        ? theme.colorScheme.primary
                        : theme.colorScheme.error,
                  ),
                  title: Text(entry.key),
                  subtitle: Text(
                    fileName,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: fileExists
                          ? theme.colorScheme.onSurface.withAlpha(140)
                          : theme.colorScheme.error,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: theme.colorScheme.error,
                    onPressed: () {
                      audioNotifier.removeTrackForArea(entry.key);
                      setState(() {}); // Refresh the list.
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFilePath = result.files.single.path);
    }
  }

  void _addMapping(AudioUiNotifier notifier) {
    final area = _selectedArea;
    final path = _selectedFilePath;

    if (area == null || path == null) return;

    // Validate file exists.
    if (!File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File not found: $path'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    notifier.setTrackForArea(area, path);
    setState(() {
      _selectedFilePath = null;
      _selectedArea = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Track assigned to $area'),
        backgroundColor: Colors.green.shade800,
      ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Setup Help'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'How area audio works:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '1. Place your MP3 files anywhere on your device.\n'
                '2. Assign each file to a game area using this screen.\n'
                '3. When your character enters that area in the game, '
                'the track will automatically start playing.\n'
                '4. Moving to a different area crossfades to that area\'s track.\n'
                '5. Areas with no assigned track will fade to silence.',
              ),
              SizedBox(height: 16),
              Text(
                'Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• Use loopable ambient tracks for the best experience.\n'
                '• Area detection uses your character\'s coordinates.\n'
                '• Set a custom prompt in-game with coordinates for best results.\n'
                '• Volume and crossfade timing can be adjusted per-area.',
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
