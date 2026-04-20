import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a child so pressing Escape pops the current route.
///
/// Binds `LogicalKeyboardKey.escape` via [CallbackShortcuts] and parks an
/// autofocus [Focus] inside so the binding has somewhere to attach when the
/// route first opens (otherwise a brand-new screen with no focused widget
/// wouldn't receive the key event).
class EscapeDismiss extends StatelessWidget {
  final Widget child;

  const EscapeDismiss({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).maybePop(),
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }
}
