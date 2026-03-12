import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/background_image_provider.dart';
import '../../providers/game_state_provider.dart';

/// Screen for managing area-to-image background mappings.
///
/// Users can assign image files to each detected area. When the player
/// enters that area, the image is displayed behind the terminal text.
class BackgroundImageSettingsScreen extends ConsumerStatefulWidget {
  const BackgroundImageSettingsScreen({super.key});

  @override
  ConsumerState<BackgroundImageSettingsScreen> createState() =>
      _BackgroundImageSettingsScreenState();
}

class _BackgroundImageSettingsScreenState
    extends ConsumerState<BackgroundImageSettingsScreen> {
  String? _selectedFilePath;
  String? _selectedArea;

  @override
  Widget build(BuildContext context) {
    final areaDetector = ref.watch(areaDetectorProvider).value;
    final managerAsync = ref.watch(areaBackgroundManagerProvider);
    final manager = managerAsync.value;
    final userImages = manager?.userImageMap ?? const {};
    final theme = Theme.of(context);

    final areas =
        areaDetector?.areas.map((a) => a.name).toList() ?? <String>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Background Images')),
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
                      Icon(Icons.image,
                          color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Area Background Images',
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
                    'Assign images to game areas. When you enter an area, '
                    'the image is displayed behind the terminal text at low '
                    'opacity so text remains readable.',
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
                    'Add Image Mapping',
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

                  // Preview of selected image.
                  if (_selectedFilePath != null &&
                      File(_selectedFilePath!).existsSync())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_selectedFilePath!),
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                  // Add button.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Assign Image'),
                      onPressed: _selectedArea != null &&
                              _selectedFilePath != null
                          ? _addMapping
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

          if (userImages.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No image mappings yet.\n'
                    'Assign images to areas above.',
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
            ...userImages.entries.map((entry) {
              final fileName = entry.value.split('/').last.split('\\').last;
              final fileExists = File(entry.value).existsSync();

              return Card(
                child: ListTile(
                  leading: fileExists
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(
                            File(entry.value),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(Icons.error_outline,
                          color: theme.colorScheme.error),
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
                      manager?.removeImageForArea(entry.key);
                      ref.invalidate(backgroundImageProvider);
                      setState(() {});
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
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _selectedFilePath = result.files.single.path);
    }
  }

  void _addMapping() {
    final area = _selectedArea;
    final path = _selectedFilePath;
    if (area == null || path == null) return;

    if (!File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File not found: $path'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final manager = ref.read(areaBackgroundManagerProvider).value;
    if (manager == null) return;
    manager.setImageForArea(area, path);
    ref.invalidate(backgroundImageProvider);
    setState(() {
      _selectedFilePath = null;
      _selectedArea = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Background image assigned to $area'),
        backgroundColor: Colors.green.shade800,
      ),
    );
  }
}
