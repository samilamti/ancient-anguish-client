import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/alias_rule.dart';
import '../../providers/alias_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/common/escape_dismiss.dart';

/// Settings screen for managing command aliases.
///
/// Aliases expand short keywords into longer commands before
/// they are sent to the MUD.
///
/// Pass [focusAliasId] to land on a specific alias — the list scrolls to
/// it, the row briefly flashes, and the edit screen opens automatically.
/// Used by the D-Pad's long-press handler on pinned alias buttons so the
/// user can jump straight from "this slot is wrong" to fixing it.
class AliasSettingsScreen extends ConsumerStatefulWidget {
  final String? focusAliasId;

  const AliasSettingsScreen({super.key, this.focusAliasId});

  @override
  ConsumerState<AliasSettingsScreen> createState() =>
      _AliasSettingsScreenState();
}

class _AliasSettingsScreenState extends ConsumerState<AliasSettingsScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _flashAliasId;

  /// Rough per-tile height — used to estimate a scroll offset before the
  /// ListView has laid out, since we can't measure unbuilt tiles. A bit
  /// generous so the target row is comfortably on-screen.
  static const double _approxTileHeight = 76.0;

  @override
  void initState() {
    super.initState();
    final id = widget.focusAliasId;
    if (id == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final aliases = ref.read(aliasRulesProvider);
      final index = aliases.indexWhere((a) => a.id == id);
      if (index < 0) return;

      if (_scrollController.hasClients) {
        final target = (index * _approxTileHeight)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }

      setState(() => _flashAliasId = id);
      _showEditDialog(context, ref, aliases[index]);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aliases = ref.watch(aliasRulesProvider);
    final pinnedIds = ref.watch(
        settingsProvider.select((s) => s.pinnedAliasIds));
    final theme = Theme.of(context);

    return EscapeDismiss(
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Command Aliases'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Help',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: aliases.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.short_text,
                    size: 64,
                    color: theme.colorScheme.primary.withAlpha(80),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No aliases configured',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add a command alias',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: aliases.length,
              itemBuilder: (context, index) {
                final alias = aliases[index];
                final isPinned = pinnedIds.contains(alias.id);
                return _AliasTile(
                  alias: alias,
                  isPinned: isPinned,
                  isFlashing: _flashAliasId == alias.id,
                  onFlashComplete: () {
                    if (_flashAliasId == alias.id) {
                      setState(() => _flashAliasId = null);
                    }
                  },
                  onToggle: () {
                    ref.read(aliasRulesProvider.notifier).toggleRule(alias.id);
                  },
                  onTogglePin: () {
                    final nowPinned = ref
                        .read(settingsProvider.notifier)
                        .toggleAliasPin(alias.id);
                    if (nowPinned &&
                        pinnedIds.length >= AppSettings.maxPinnedAliases &&
                        !pinnedIds.contains(alias.id)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Pinned "${alias.keyword}" — '
                            'oldest quick-slot was bumped out.',
                          ),
                        ),
                      );
                    }
                  },
                  onEdit: () => _showEditDialog(context, ref, alias),
                  onDelete: () {
                    ref.read(aliasRulesProvider.notifier).removeRule(alias.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Deleted "${alias.keyword}"')),
                    );
                  },
                );
              },
            ),
    ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Aliases'),
        content: const SingleChildScrollView(
          child: Text(
            'Aliases expand short keywords into full commands '
            'before sending to the MUD.\n\n'
            'Variable substitution:\n'
            '• \$0 — Everything after the keyword\n'
            '• \$1, \$2, ... — Individual arguments\n\n'
            'Examples:\n'
            '• "k" → "kill \$1"\n'
            '  Typing "k goblin" sends "kill goblin"\n\n'
            '• "c" → "cast \$0"\n'
            '  Typing "c fireball at goblin" sends\n'
            '  "cast fireball at goblin"\n\n'
            '• "ga" → "get all"\n'
            '  Typing "ga" sends "get all"',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, AliasRule? existing) {
    openAliasEditor(context, existing: existing);
  }
}

/// Opens the alias create/edit screen as a pushed route.
///
/// Pass [existing] to edit a rule, or [initialExpansion] to start a brand-new
/// alias with the "Expands to" field pre-filled — used by the Recent-commands
/// sheet's "+" button so the user can turn a command they just typed into an
/// alias in one tap, then only has to name it.
Future<void> openAliasEditor(
  BuildContext context, {
  AliasRule? existing,
  String? initialExpansion,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _AliasEditScreen(
        existing: existing,
        initialExpansion: initialExpansion,
      ),
    ),
  );
}

/// List tile for a single alias rule.
class _AliasTile extends StatefulWidget {
  final AliasRule alias;
  final bool isPinned;
  final bool isFlashing;
  final VoidCallback onToggle;
  final VoidCallback onTogglePin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onFlashComplete;

  const _AliasTile({
    required this.alias,
    required this.isPinned,
    this.isFlashing = false,
    required this.onToggle,
    required this.onTogglePin,
    required this.onEdit,
    required this.onDelete,
    this.onFlashComplete,
  });

  @override
  State<_AliasTile> createState() => _AliasTileState();
}

class _AliasTileState extends State<_AliasTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flashController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isFlashing) _startFlash();
  }

  @override
  void didUpdateWidget(covariant _AliasTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlashing && !oldWidget.isFlashing) _startFlash();
  }

  void _startFlash() {
    _flashController.forward(from: 0).whenComplete(() {
      if (mounted) widget.onFlashComplete?.call();
    });
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alias = widget.alias;
    final isPinned = widget.isPinned;
    final onToggle = widget.onToggle;
    final onTogglePin = widget.onTogglePin;
    final onEdit = widget.onEdit;
    final onDelete = widget.onDelete;

    final tile = ListTile(
      leading: Icon(
        Icons.short_text,
        color: alias.enabled
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurface.withAlpha(60),
      ),
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: alias.keyword,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.bold,
                color: alias.enabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
            TextSpan(
              text: '  →  ',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withAlpha(80),
              ),
            ),
            TextSpan(
              text: alias.expansion,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                color: alias.enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withAlpha(100),
              ),
            ),
          ],
        ),
      ),
      subtitle: alias.description != null
          ? Text(
              alias.description!,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withAlpha(80),
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isPinned ? Icons.star : Icons.star_border,
              color: isPinned
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withAlpha(120),
            ),
            tooltip: isPinned
                ? 'Unpin from mobile quick slot'
                : 'Pin to mobile quick slot',
            onPressed: onTogglePin,
          ),
          Switch(
            value: alias.enabled,
            onChanged: (_) => onToggle(),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );

    // Flash background highlight when this tile is the long-press target,
    // so the user's eye lands on the right row when the edit sheet closes.
    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, child) {
        if (_flashController.isDismissed) return child!;
        // Pulse from full → transparent over the animation's lifetime.
        final t = _flashController.value;
        final alpha = ((1.0 - t).clamp(0.0, 1.0) * 90).round();
        return Container(
          color: theme.colorScheme.primary.withAlpha(alpha),
          child: child,
        );
      },
      child: tile,
    );
  }
}

/// Edit/create screen for a single alias rule.
class _AliasEditScreen extends ConsumerStatefulWidget {
  final AliasRule? existing;

  /// Pre-fills the "Expands to" field for a new alias. Ignored when [existing]
  /// is set (an edit always uses the rule's own expansion).
  final String? initialExpansion;

  const _AliasEditScreen({this.existing, this.initialExpansion});

  @override
  ConsumerState<_AliasEditScreen> createState() => _AliasEditScreenState();
}

class _AliasEditScreenState extends ConsumerState<_AliasEditScreen> {
  late final TextEditingController _keywordController;
  late final TextEditingController _expansionController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _testInputController;
  String? _previewOutput;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _keywordController = TextEditingController(text: e?.keyword ?? '');
    _expansionController = TextEditingController(
      text: e?.expansion ?? widget.initialExpansion ?? '',
    );
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _testInputController = TextEditingController();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _expansionController.dispose();
    _descriptionController.dispose();
    _testInputController.dispose();
    super.dispose();
  }

  void _testExpansion() {
    final keyword = _keywordController.text.trim();
    final expansion = _expansionController.text.trim();
    final testInput = _testInputController.text.trim();

    if (keyword.isEmpty || expansion.isEmpty || testInput.isEmpty) {
      setState(() => _previewOutput = null);
      return;
    }

    final testAlias = AliasRule(
      id: 'test',
      keyword: keyword,
      expansion: expansion,
    );

    final result = testAlias.tryExpand(testInput);
    setState(() {
      _previewOutput = result ?? '(no match — input must start with "$keyword")';
    });
  }

  void _save() {
    final keyword = _keywordController.text.trim();
    final expansion = _expansionController.text.trim();

    if (keyword.isEmpty || expansion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keyword and expansion are required')),
      );
      return;
    }

    // Validate: keyword must not contain spaces.
    if (keyword.contains(' ')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keyword must be a single word')),
      );
      return;
    }

    final rule = AliasRule(
      id: widget.existing?.id ??
          'alias_${DateTime.now().millisecondsSinceEpoch}',
      keyword: keyword,
      expansion: expansion,
      enabled: widget.existing?.enabled ?? true,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    final notifier = ref.read(aliasRulesProvider.notifier);
    if (widget.existing != null) {
      notifier.updateRule(rule);
    } else {
      notifier.addRule(rule);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final mib = ref.watch(settingsProvider.select((s) => s.mobileInput));

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Alias' : 'New Alias'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('SAVE'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Keyword field. When the expansion was pre-filled (from the
          // Recent-commands "+" button), focus the keyword so the user can
          // name the alias immediately.
          TextField(
            controller: _keywordController,
            autofocus: widget.existing == null &&
                widget.initialExpansion != null,
            autocorrect: mib.autocorrect,
            enableSuggestions: mib.enableSuggestions,
            smartDashesType: mib.smartDashesType,
            smartQuotesType: mib.smartQuotesType,
            decoration: const InputDecoration(
              labelText: 'Keyword',
              hintText: 'e.g., k, ga, c',
              helperText: 'The short word you type (no spaces)',
            ),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Expansion field.
          TextField(
            controller: _expansionController,
            autocorrect: mib.autocorrect,
            enableSuggestions: mib.enableSuggestions,
            smartDashesType: mib.smartDashesType,
            smartQuotesType: mib.smartQuotesType,
            decoration: const InputDecoration(
              labelText: 'Expands to',
              hintText: r'e.g., kill $1',
              helperText: r'Use $0 for all args, $1 $2 for individual args',
              helperMaxLines: 2,
            ),
            style: const TextStyle(fontFamily: 'JetBrainsMono'),
          ),
          const SizedBox(height: 16),

          // Description field.
          TextField(
            controller: _descriptionController,
            autocorrect: mib.autocorrect,
            enableSuggestions: mib.enableSuggestions,
            smartDashesType: mib.smartDashesType,
            smartQuotesType: mib.smartQuotesType,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              hintText: 'e.g., Kill a target',
            ),
          ),
          const SizedBox(height: 24),

          // Test area.
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Test Your Alias',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testInputController,
                  autocorrect: mib.autocorrect,
                  enableSuggestions: mib.enableSuggestions,
                  smartDashesType: mib.smartDashesType,
                  smartQuotesType: mib.smartQuotesType,
                  decoration: const InputDecoration(
                    labelText: 'Test input',
                    hintText: 'e.g., k goblin',
                    isDense: true,
                  ),
                  style: const TextStyle(fontFamily: 'JetBrainsMono'),
                  onChanged: (_) => _testExpansion(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: _testExpansion,
                tooltip: 'Test expansion',
              ),
            ],
          ),
          if (_previewOutput != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '> $_previewOutput',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  color: Color(0xFF55FF55),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
