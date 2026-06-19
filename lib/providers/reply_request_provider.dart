import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A one-shot "reply to the latest tell" signal.
///
/// Fired by the Ctrl/Cmd+R desktop shortcut. The Tells [SocialInputBar]
/// listens and pre-fills [recipient] in the name field then focuses the
/// message field; the Tells [SocialMessageList] listens and scrolls to the
/// newest tell. [seq] increments on every request so consumers react even
/// when the recipient is unchanged (re-pressing Reply for the same partner).
class ReplyRequest {
  final String? recipient;
  final int seq;

  const ReplyRequest({required this.recipient, required this.seq});
}

/// Holds the most recent reply request, or null before the first one.
class ReplyRequestNotifier extends Notifier<ReplyRequest?> {
  @override
  ReplyRequest? build() => null;

  /// Signals a reply to [recipient] (the sender of the latest incoming tell,
  /// or null when there is no tell to reply to).
  void reply(String? recipient) {
    final next = (state?.seq ?? 0) + 1;
    state = ReplyRequest(recipient: recipient, seq: next);
  }
}

final replyRequestProvider =
    NotifierProvider<ReplyRequestNotifier, ReplyRequest?>(
        ReplyRequestNotifier.new);
