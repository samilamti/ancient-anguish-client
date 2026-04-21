import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/login_provider.dart';
import '../../../providers/settings_provider.dart';

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
  bool _remember = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final name = (_acController?.text ?? '').trim();
    final password = _passwordController.text;
    if (name.isEmpty) return;
    ref.read(loginProvider.notifier).submitCredentials(name, password, _remember);
  }

  void _quickLogin(SavedAlt alt) {
    ref.read(loginProvider.notifier).submitCredentials(alt.name, alt.password, false);
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

    return Center(
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surface,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.primary.withAlpha(80),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
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

              // Quick-login buttons for saved characters.
              if (alts.isNotEmpty) ...[
                for (final alt in alts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.only(left: 12),
                        side: BorderSide(
                          color: theme.colorScheme.primary.withAlpha(100),
                        ),
                      ),
                      onPressed: () => _quickLogin(alt),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 18,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alt.name,
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            color: theme.colorScheme.onSurface.withAlpha(120),
                            onPressed: () => _confirmRemove(alt),
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
                      Expanded(child: Divider(
                        color: theme.colorScheme.onSurface.withAlpha(40),
                      )),
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
                      Expanded(child: Divider(
                        color: theme.colorScheme.onSurface.withAlpha(40),
                      )),
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
                  return names.where(
                    (a) => a.toLowerCase().contains(lower),
                  );
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
                  TextButton(
                    onPressed: _cancel,
                    child: const Text('Cancel'),
                  ),
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
    );
  }
}
