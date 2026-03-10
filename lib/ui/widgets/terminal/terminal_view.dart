import 'dart:async';

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SelectedContent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../protocol/ansi/styled_span.dart';
import '../../../providers/connection_provider.dart'
    show terminalBufferProvider, inputFocusProvider;
import 'terminal_selection_controller.dart';

/// The main terminal output widget.
///
/// Displays the scrollback buffer as a scrollable list of styled text lines.
/// Uses [ListView.builder] for efficient rendering of large buffers.
/// Supports text selection via [SelectionArea] with auto-copy on drag release.
class TerminalView extends ConsumerStatefulWidget {
  const TerminalView({super.key});

  @override
  ConsumerState<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends ConsumerState<TerminalView> {
  final ScrollController _scrollController = ScrollController();
  final TerminalSelectionController _selectionController =
      TerminalSelectionController();
  bool _autoScroll = true;

  // Pointer-based tap detection (replaces GestureDetector to avoid
  // competing with SelectionArea in the gesture arena).
  int _tapCount = 0;
  DateTime _lastPointerDown = DateTime(0);
  Offset _lastPointerDownPosition = Offset.zero;
  bool _pointerMoved = false;
  Timer? _tapTimer;

  static const double _tapSlopSquared = 18.0 * 18.0;
  static const Duration _doubleTapTimeout = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final wasAutoScroll = _autoScroll;
    _autoScroll = position.pixels >= position.maxScrollExtent - 50;
    if (wasAutoScroll != _autoScroll) {
      setState(() {});
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  // ---------------------------------------------------------------------------
  // Pointer-based tap / double-tap detection
  // ---------------------------------------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    _pointerMoved = false;
    _lastPointerDownPosition = event.position;
    _lastPointerDown = DateTime.now();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointerMoved) return;
    final delta = event.position - _lastPointerDownPosition;
    if (delta.distanceSquared > _tapSlopSquared) {
      _pointerMoved = true;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    // Auto-copy when user finishes a drag-to-select gesture.
    if (_selectionController.hasSelection && _pointerMoved) {
      _selectionController.copySelectionToClipboard();
      return;
    }

    // --- Tap detection ---
    final timeSinceDown = DateTime.now().difference(_lastPointerDown);
    if (_pointerMoved || timeSinceDown > const Duration(milliseconds: 500)) {
      _resetTapState();
      return;
    }

    final delta = event.position - _lastPointerDownPosition;
    if (delta.distanceSquared > _tapSlopSquared) {
      _resetTapState();
      return;
    }

    _tapCount++;

    if (_tapCount == 1) {
      _tapTimer?.cancel();
      _tapTimer = Timer(_doubleTapTimeout, () {
        _handleSingleTap();
        _resetTapState();
      });
    } else if (_tapCount >= 2) {
      _tapTimer?.cancel();
      _handleDoubleTap();
      _resetTapState();
    }
  }

  void _resetTapState() {
    _tapCount = 0;
    _tapTimer?.cancel();
    _tapTimer = null;
  }

  void _handleSingleTap() {
    if (_selectionController.hasSelection) {
      // Tap while text is selected — just deselect, don't focus input.
      return;
    }
    ref.read(inputFocusProvider).requestFocus();
  }

  void _handleDoubleTap() {
    setState(() {
      _autoScroll = true;
    });
    _scrollToBottom();
  }

  // ---------------------------------------------------------------------------
  // Selection tracking
  // ---------------------------------------------------------------------------

  void _onSelectionChanged(SelectedContent? content) {
    final changed = _selectionController.onSelectionChanged(content);
    if (changed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(terminalBufferProvider);

    // Auto-scroll when new lines arrive.
    ref.listen<List<StyledLine>>(terminalBufferProvider, (previous, next) {
      if (_autoScroll && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Stack(
          children: [
            // Terminal output – SelectionArea enables click-drag text selection
            // and auto-copies to clipboard on release.
            SelectionArea(
              onSelectionChanged: _onSelectionChanged,
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                // Keep extra off-screen lines alive to improve selection
                // continuity across scroll boundaries.
                cacheExtent: 2000,
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  return _TerminalLine(line: lines[index]);
                },
              ),
            ),

            // "Scroll to bottom" indicator when not auto-scrolling.
            if (!_autoScroll)
              Positioned(
                bottom: 8,
                right: 8,
                child: FloatingActionButton.small(
                  onPressed: () {
                    setState(() {
                      _autoScroll = true;
                    });
                    _scrollToBottom();
                  },
                  child: const Icon(Icons.arrow_downward),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single line of styled terminal output.
class _TerminalLine extends StatelessWidget {
  final StyledLine line;

  const _TerminalLine({required this.line});

  @override
  Widget build(BuildContext context) {
    if (line.spans.isEmpty) {
      // Empty line – still needs to take up space.
      return const SizedBox(height: 18);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: RichText(
        text: line.toTextSpan(
          fontFamily: TerminalDefaults.fontFamily,
          fontSize: TerminalDefaults.fontSize,
        ),
        softWrap: true,
      ),
    );
  }
}
