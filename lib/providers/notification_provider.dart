import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a notification stays fully visible before it fades out.
const Duration kNotificationDuration = Duration(seconds: 2);

/// At most this many notifications stack at once; older ones are dropped.
///
/// Three is enough that a burst (say two failed file loads) is all readable,
/// and few enough that the stack can never march down over the output it is
/// reporting on.
const int kMaxVisibleNotifications = 3;

/// A transient message shown over the top of the MUD output.
///
/// Replaces `ScaffoldMessenger.showSnackBar` for anything raised while the game
/// screen is on show: SnackBars are bottom-anchored (there is no top option),
/// which put them over the input bar and the newest lines — and one carrying an
/// action is not auto-dismissed at all when accessible navigation is on, which
/// is how the "Ignoring '…'" confirmation came to sit there indefinitely.
@immutable
class AppNotification {
  /// Identity for the list, and the handle [AppNotificationsNotifier.dismiss]
  /// takes. Monotonic per session, so a re-shown message is a new notification
  /// rather than a resurrected one.
  final int id;
  final String message;

  /// Optional single action, e.g. "Undo". Tapping it runs [onAction] and
  /// dismisses the notification immediately.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Visible hold before the fade-out starts.
  final Duration duration;

  /// Paints in the error colour — for failures, as opposed to confirmations.
  final bool isError;

  const AppNotification({
    required this.id,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.duration = kNotificationDuration,
    this.isError = false,
  });
}

/// The notifications currently on screen, oldest first.
final appNotificationsProvider =
    NotifierProvider<AppNotificationsNotifier, List<AppNotification>>(
  AppNotificationsNotifier.new,
);

class AppNotificationsNotifier extends Notifier<List<AppNotification>> {
  int _nextId = 0;

  @override
  List<AppNotification> build() => const [];

  /// Queues [message] and returns its id.
  ///
  /// Expiry is the overlay's job rather than the notifier's — the card has to
  /// finish fading before it can be removed from the list, and it owns that
  /// animation. Nothing else calls [dismiss], so a notification raised while no
  /// overlay is mounted simply waits for one, which is what makes a message
  /// raised from a settings pane still legible when it lands on the game screen.
  int show(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = kNotificationDuration,
    bool isError = false,
  }) {
    final id = _nextId++;
    final next = [
      ...state,
      AppNotification(
        id: id,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        isError: isError,
      ),
    ];
    state = next.length > kMaxVisibleNotifications
        ? next.sublist(next.length - kMaxVisibleNotifications)
        : next;
    return id;
  }

  /// Removes [id] if it is still showing. Idempotent: two overlays can be
  /// mounted at once (the game screen's, plus a pushed screen's), and both run
  /// their own fade timers for the same notification.
  void dismiss(int id) {
    if (!state.any((n) => n.id == id)) return;
    state = [
      for (final notification in state)
        if (notification.id != id) notification,
    ];
  }

  void clear() => state = const [];
}
