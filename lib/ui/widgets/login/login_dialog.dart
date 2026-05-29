import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/login_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/social_panel_provider.dart' show isDesktopPlatform;

/// Overlay dialog for entering login credentials or choosing guest.
class LoginDialog extends ConsumerStatefulWidget {
  const LoginDialog({super.key});

  @override
  ConsumerState<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends ConsumerState<LoginDialog> {
  // Reference to Autocomplete's internal controller, set in fieldViewBuilder.
  TextEditingController? _acController;
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  // Holds focus for the number-key quick-login shortcuts so digits don't leak
  // into a text field. See [build] for why it's grabbed explicitly.
  final _dialogFocus = FocusNode();
  bool _grabbedDialogFocus = false;
  bool _remember = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    _dialogFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final name = (_acController?.text ?? '').trim();
    final password = _passwordController.text;
    if (name.isEmpty) return;
    ref
        .read(loginProvider.notifier)
        .submitCredentials(name, password, _remember);
  }

  void _quickLogin(SavedAlt alt) {
    // remember: true so the lastPlayed timestamp gets refreshed on the saved alt.
    ref
        .read(loginProvider.notifier)
        .submitCredentials(alt.name, alt.password, true);
  }

  /// Number-key shortcuts (1-9) for the first nine saved characters, in the
  /// order they're listed: press `1` to log in the first character, `2` the
  /// second, and so on. Desktop quality-of-life. These only fire while no
  /// text field in the dialog holds focus — a focused field consumes the
  /// digit instead — which is why the dialog wraps its body in a [Focus] that
  /// is given focus on desktop (see [build]).
  Map<ShortcutActivator, VoidCallback> _altShortcuts(List<SavedAlt> alts) {
    const digits = <LogicalKeyboardKey>[
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    final count = alts.length < digits.length ? alts.length : digits.length;
    final bindings = <ShortcutActivator, VoidCallback>{};
    for (var i = 0; i < count; i++) {
      final alt = alts[i];
      bindings[SingleActivator(digits[i])] = () => _quickLogin(alt);
    }
    return bindings;
  }

  String _formatRelative(DateTime ts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tsDay = DateTime(ts.year, ts.month, ts.day);
    final days = today.difference(tsDay).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'yesterday';
    if (days < 7) return '${days}d ago';
    if (days < 30) return '${days ~/ 7}w ago';
    if (days < 365) return '${days ~/ 30}mo ago';
    return '${days ~/ 365}y ago';
  }

  void _confirmRemove(SavedAlt alt) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove character?'),
        content: Text('Remove ${alt.name} from saved characters?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) {
        ref.read(loginProvider.notifier).removeAlt(alt.name);
      }
    });
  }

  void _guest() {
    ref.read(loginProvider.notifier).submitGuest();
  }

  void _cancel() {
    ref.read(loginProvider.notifier).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alts = ref.watch(savedAltsProvider).value ?? <SavedAlt>[];
    final mib = ref.watch(settingsProvider.select((s) => s.mobileInput));

    // Number-key quick-login (1-9). For these to fire, the dialog's Focus —
    // not a text field — must hold focus. Saved alts load asynchronously, so
    // the name field (autofocus: alts.isEmpty) grabs focus on first build
    // before they arrive; once they do, claim focus back to the dialog, once,
    // so digits log in rather than typing into the field. With no saved alts
    // we leave the name field focused for manual entry. Desktop-only: it's a
    // hardware-keyboard feature, and skipping it on mobile avoids yanking the
    // soft keyboard away from the name field.
    if (alts.isNotEmpty && !_grabbedDialogFocus && isDesktopPlatform()) {
      _grabbedDialogFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _dialogFocus.requestFocus();
      });
    }

    final body = Center(
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.primary.withAlpha(80)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title.
                Text(
                  'Login',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // Quick-login buttons for saved characters (scrolls when many).
                if (alts.isNotEmpty) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, alt) in alts.indexed)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        side: BorderSide(
                                          color: theme.colorScheme.primary
                                              .withAlpha(100),
                                        ),
                                        alignment: Alignment.centerLeft,
                                      ),
                                      onPressed: () => _quickLogin(alt),
                                      child: Row(
                                        children: [
                                          // First nine entries show their
                                          // number-key shortcut (press 1-9);
                                          // the rest fall back to a person icon.
                                          SizedBox(
                                            width: 18,
                                            child: i < 9
                                                ? Text(
                                                    '${i + 1}',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                      fontFamily:
                                                          'JetBrainsMono',
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: theme
                                                          .colorScheme.primary,
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.person,
                                                    size: 18,
                                                    color: theme
                                                        .colorScheme.primary,
                                                  ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  alt.name,
                                                  style: const TextStyle(
                                                    fontFamily: 'JetBrainsMono',
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                if (alt.lastPlayed != null)
                                                  Text(
                                                    _formatRelative(
                                                      alt.lastPlayed!,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: theme
                                                          .colorScheme
                                                          .onSurface
                                                          .withAlpha(140),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 22,
                                    ),
                                    color: theme.colorScheme.onSurface
                                        .withAlpha(160),
                                    tooltip: 'Remove ${alt.name}',
                                    onPressed: () => _confirmRemove(alt),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Divider between quick-login and manual form.
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: theme.colorScheme.onSurface.withAlpha(40),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or login manually',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withAlpha(100),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: theme.colorScheme.onSurface.withAlpha(40),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Character name with autocomplete.
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    final names = alts.map((a) => a.name).toList();
                    if (textEditingValue.text.isEmpty) return names;
                    final lower = textEditingValue.text.toLowerCase();
                    return names.where((a) => a.toLowerCase().contains(lower));
                  },
                  onSelected: (value) {
                    _passwordFocus.requestFocus();
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        _acController = controller;
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          autofocus: alts.isEmpty,
                          autocorrect: mib.autocorrect,
                          enableSuggestions: mib.enableSuggestions,
                          smartDashesType: mib.smartDashesType,
                          smartQuotesType: mib.smartQuotesType,
                          decoration: const InputDecoration(
                            labelText: 'Character name',
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                            isDense: true,
                          ),
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 14,
                          ),
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 200,
                            maxWidth: 272,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(
                                  option,
                                  style: const TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 13,
                                  ),
                                ),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Password field.
                TextField(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                    isDense: true,
                  ),
                  style: const TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14,
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),

                // Remember checkbox.
                CheckboxListTile(
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v ?? true),
                  title: Text(
                    'Remember character',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withAlpha(200),
                    ),
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),

                // Action buttons.
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _guest,
                      child: const Text('Guest'),
                    ),
                    const Spacer(),
                    TextButton(onPressed: _cancel, child: const Text('Cancel')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return CallbackShortcuts(
      bindings: _altShortcuts(alts),
      child: Focus(focusNode: _dialogFocus, child: body),
    );
  }
}
