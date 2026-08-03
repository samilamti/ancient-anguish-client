import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../providers/notification_provider.dart';

/// How long a notification takes to fade out once its hold has elapsed.
const Duration kNotificationFadeDuration = Duration(milliseconds: 220);

/// Widest a notification card gets, so a long message wraps instead of
/// stretching across a desktop-width terminal.
const double _kMaxWidth = 460;

/// Stack of transient notifications, anchored to the **top** of whatever it is
/// laid over.
///
/// Meant to be dropped into the `Stack` that already holds the terminal, so the
/// messages land at the top of the MUD output rather than over the input bar and
/// the newest lines the way a bottom SnackBar did. Takes no space and swallows no
/// pointers when there is nothing to show.
class NotificationOverlay extends ConsumerWidget {
  const NotificationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(appNotificationsProvider);
    if (notifications.isEmpty) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final notification in notifications)
              _NotificationCard(
                // Keyed by id so an expiring card can't hand its half-finished
                // fade to the notification that takes its place in the list.
                key: ValueKey(notification.id),
                notification: notification,
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerStatefulWidget {
  final AppNotification notification;

  const _NotificationCard({super.key, required this.notification});

  @override
  ConsumerState<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends ConsumerState<_NotificationCard> {
  Timer? _holdTimer;
  Timer? _fadeTimer;
  double _opacity = 1;

  @override
  void initState() {
    super.initState();
    _holdTimer = Timer(widget.notification.duration, _fadeOut);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _fadeOut() {
    if (!mounted) return;
    setState(() => _opacity = 0);
    _fadeTimer = Timer(kNotificationFadeDuration, _remove);
  }

  /// Only ever reached while mounted (both timers are cancelled in [dispose]),
  /// so reading the notifier here is safe.
  void _remove() {
    if (!mounted) return;
    ref.read(appNotificationsProvider.notifier).dismiss(widget.notification.id);
  }

  void _runAction() {
    widget.notification.onAction?.call();
    _holdTimer?.cancel();
    _fadeTimer?.cancel();
    _remove();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final notification = widget.notification;
    final accent = notification.isError ? scheme.error : scheme.primary;

    return AnimatedOpacity(
      opacity: _opacity,
      duration: kNotificationFadeDuration,
      curve: Curves.easeOut,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxWidth),
          child: Material(
            color: scheme.surface.withAlpha(240),
            elevation: 4,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.only(
                left: 12,
                right: 8,
                top: 8,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accent.withAlpha(120)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      notification.message,
                      style: TextStyle(
                        fontFamily: TerminalDefaults.fontFamily,
                        fontSize: 13,
                        color: notification.isError
                            ? scheme.error
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  if (notification.actionLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: TextButton(
                        onPressed: _runAction,
                        style: TextButton.styleFrom(
                          foregroundColor: accent,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontFamily: TerminalDefaults.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: Text(notification.actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
