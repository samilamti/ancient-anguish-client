import 'dart:async';

import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../protocol/ansi/styled_span.dart';
import '../../../providers/background_image_provider.dart';
import '../../../providers/connection_provider.dart'
    show connectionServiceProvider, terminalBufferProvider, inputFocusProvider;
import '../../../providers/settings_provider.dart';
import '../../../providers/social_panel_provider.dart';
import '../../../models/social_panel_state.dart';
import '../../../services/platform/file_utils.dart';
import '../../screens/history_screen.dart';
import '../../screens/text_link_rules_screen.dart';
import 'terminal_line.dart';
import 'terminal_selection.dart';
import 'terminal_selection_controller.dart';

/// The main terminal output widget.
///
/// Renders the tail of the scrollback buffer pinned to the bottom of the
/// viewport. Lines that don't fit are clipped off the top — there is no
/// scrolling in this view. The full buffer remains accessible via the
/// dedicated [HistoryScreen] (opened from the AppBar or by double-tapping
/// the terminal).
class TerminalView extends ConsumerStatefulWidget {
  const TerminalView({super.key});

  @override
  ConsumerState<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends ConsumerState<TerminalView> {
  final TerminalSelectionController _selectionController =
      TerminalSelectionController();
  final FocusNode _focusNode = FocusNode();

  // Pointer-based tap detection (replaces GestureDetector to avoid
  // competing with SelectionArea in the gesture arena).
  int _tapCount = 0;
  DateTime _lastPointerDown = DateTime(0);
  Offset _lastPointerDownPosition = Offset.zero;
  bool _pointerMoved = false;
  bool _primaryButtonDown = false;
  Timer? _tapTimer;

  static const double _tapSlopSquared = 18.0 * 18.0;
  static const Duration _doubleTapTimeout = Duration(milliseconds: 300);

  // Monospace font measurements (recomputed when font size changes).
  double _charWidth = 0;
  double _lineHeight = 0;
  bool _fontMeasured = false;
  double _measuredFontSize = 0;

  @override
  void dispose() {
    _tapTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _measureFont(double fontSize) {
    if (_fontMeasured && fontSize == _measuredFontSize) return;
    final painter = TextPainter(
      text: TextSpan(
        text: 'M',
        style: TextStyle(
          fontFamily: TerminalDefaults.fontFamily,
          fontSize: fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    _charWidth = painter.width;
    _lineHeight = painter.height + 1.0;
    painter.dispose();
    _fontMeasured = true;
    _measuredFontSize = fontSize;
  }

  // ---------------------------------------------------------------------------
  // Hit-testing: convert pointer position → TerminalPosition
  // ---------------------------------------------------------------------------

  TerminalPosition? _hitTest(Offset localPosition, List<StyledLine> lines) {
    if (_charWidth == 0 || _lineHeight == 0 || lines.isEmpty) return null;

    final box = context.findRenderObject() as RenderBox?;
    final viewportHeight = box?.size.height ?? 0;
    if (viewportHeight == 0) return null;

    // ListView(reverse: true) anchors item 0 (the newest line) at the
    // bottom of the viewport, minus the bottom padding (vertical: 4).
    // Measure how far the pointer is from that anchor; divide by the
    // uniform line height to get a "visual row from the bottom" index.
    // Variable-height children (map blocks, framed text) will misalign
    // this math — same imperfection as the previous implementation.
    final distanceFromBottom = viewportHeight - localPosition.dy - 4.0;
    final adjustedX = localPosition.dx - 8.0;

    if (distanceFromBottom < 0) {
      final last = lines.length - 1;
      return TerminalPosition(last, lines[last].plainText.length);
    }

    final visualRow = (distanceFromBottom / _lineHeight).floor();
    if (visualRow >= lines.length) {
      return const TerminalPosition(0, 0);
    }

    final lineIndex = lines.length - 1 - visualRow;
    final lineLength = lines[lineIndex].plainText.length;
    final column = (adjustedX / _charWidth).round().clamp(0, lineLength);
    return TerminalPosition(lineIndex, column);
  }

  TerminalPosition? _hitTestAuto(Offset localPosition) {
    final lines = ref.read(terminalBufferProvider);
    return _hitTest(localPosition, lines);
  }

  // ---------------------------------------------------------------------------
  // Pointer-based tap / double-tap / selection detection
  // ---------------------------------------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons == kSecondaryButton) {
      _showContextMenu(event.position);
      return;
    }

    if (event.buttons != kPrimaryButton) return;
    _primaryButtonDown = true;
    _pointerMoved = false;
    _lastPointerDownPosition = event.position;
    _lastPointerDown = DateTime.now();

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(event.position);
    final pos = _hitTestAuto(localPos);
    if (pos == null) return;

    final shiftHeld = HardwareKeyboard.instance.logicalKeysPressed
        .any((k) =>
            k == LogicalKeyboardKey.shiftLeft ||
            k == LogicalKeyboardKey.shiftRight);

    if (shiftHeld && _selectionController.hasSelection) {
      if (_selectionController.updateSelection(pos)) setState(() {});
    } else {
      _selectionController.startSelection(pos);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_primaryButtonDown) return;

    final delta = event.position - _lastPointerDownPosition;
    if (!_pointerMoved && delta.distanceSquared > _tapSlopSquared) {
      _pointerMoved = true;
    }

    if (!_pointerMoved) return;

    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(event.position);
    final pos = _hitTestAuto(localPos);
    if (pos != null) {
      if (_selectionController.updateSelection(pos)) setState(() {});
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _primaryButtonDown = false;

    if (_selectionController.hasSelection && _pointerMoved) {
      final sel = _selectionController.selection!;
      if (sel.anchor != sel.focus) {
        // A real selection was made by dragging — surface the context menu so
        // the user can copy it or turn it into a text link rule.
        _focusNode.requestFocus();
        _showContextMenu(event.position);
        return;
      }
    }

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
    final sel = _selectionController.selection;
    if (sel != null && sel.anchor != sel.focus) {
      _selectionController.clearSelection();
      setState(() {});
      return;
    }
    _selectionController.clearSelection();
    ref.read(inputFocusProvider).requestFocus();
  }

  /// Double-tap opens the dedicated history screen. The live terminal is
  /// pinned to the bottom by construction, so the previous "snap to
  /// bottom" gesture has nothing to do.
  void _handleDoubleTap() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
  }

  /// Dispatches a tap on a text-to-link span — sends the command to the
  /// MUD. The tail is already pinned, so no scroll action is needed.
  void _sendLinkCommand(String command) {
    if (command.trim().isEmpty) return;
    ref.read(connectionServiceProvider).sendCommand(command);
  }

  // ---------------------------------------------------------------------------
  // Keyboard shortcuts
  // ---------------------------------------------------------------------------

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final ctrl = HardwareKeyboard.instance.logicalKeysPressed.any((k) =>
        k == LogicalKeyboardKey.controlLeft ||
        k == LogicalKeyboardKey.controlRight);

    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyC) {
      if (_selectionController.hasSelection) {
        _selectionController.copyToClipboard(ref.read(terminalBufferProvider));
        return KeyEventResult.handled;
      }
    }

    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyA) {
      final lines = ref.read(terminalBufferProvider);
      if (lines.isNotEmpty) {
        final lastLine = lines.last;
        if (_selectionController.selectAll(
            lines.length, lastLine.plainText.length)) {
          setState(() {});
        }
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_selectionController.clearSelection()) {
        setState(() {});
      }
      return KeyEventResult.handled;
    }

    // Ctrl/Cmd+1/2/3 to switch social tabs.
    final ctrlOrCmd = ctrl ||
        HardwareKeyboard.instance.logicalKeysPressed.any((k) =>
            k == LogicalKeyboardKey.metaLeft ||
            k == LogicalKeyboardKey.metaRight);
    if (ctrlOrCmd) {
      int? tabIndex;
      if (event.logicalKey == LogicalKeyboardKey.digit1) tabIndex = 0;
      if (event.logicalKey == LogicalKeyboardKey.digit2) tabIndex = 1;
      if (event.logicalKey == LogicalKeyboardKey.digit3) tabIndex = 2;
      if (tabIndex != null) {
        final panelState = ref.read(socialPanelProvider);
        if (panelState.tabMode == PanelTabMode.tabbed) {
          ref.read(socialPanelProvider.notifier).setActiveTab(tabIndex);
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Context menu
  // ---------------------------------------------------------------------------

  void _showContextMenu(Offset globalPosition) {
    final lines = ref.read(terminalBufferProvider);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final localPos = box.globalToLocal(globalPosition);
    final hitPos = _hitTestAuto(localPos);

    final overlay = Overlay.of(context);
    final renderBox = overlay.context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlayPos = renderBox.globalToLocal(globalPosition);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        overlayPos.dx,
        overlayPos.dy,
        overlayPos.dx,
        overlayPos.dy,
      ),
      items: [
        if (_selectionController.hasSelection)
          const PopupMenuItem(value: 'copy', child: Text('Copy')),
        if (_selectionController.hasSelection)
          const PopupMenuItem(
            value: 'create_text_link_rule',
            child: Text('Create Text Link Rule'),
          ),
        if (hitPos != null)
          const PopupMenuItem(value: 'copy_line', child: Text('Copy Line')),
        const PopupMenuItem(value: 'select_all', child: Text('Select All')),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'copy':
          _selectionController.copyToClipboard(lines);
        case 'create_text_link_rule':
          final selected =
              _selectionController.selection?.extractText(lines) ?? '';
          if (selected.trim().isNotEmpty && mounted) {
            openTextLinkRuleEditor(context, initialMatchText: selected);
          }
        case 'copy_line':
          if (hitPos != null && hitPos.line < lines.length) {
            final lineText = lines[hitPos.line].plainText;
            Clipboard.setData(ClipboardData(text: lineText));
          }
        case 'select_all':
          if (lines.isNotEmpty) {
            if (_selectionController.selectAll(
                lines.length, lines.last.plainText.length)) {
              setState(() {});
            }
          }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final fontSize = settings.fontSize;
    _measureFont(fontSize);
    final lines = ref.watch(terminalBufferProvider);
    final selection = _selectionController.selection;
    final bgImagePath = ref.watch(backgroundImageProvider);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            children: [
              // Area background image.
              if (bgImagePath != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.12,
                    child: buildFileImage(
                      bgImagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),

              // Tail-only terminal output. `reverse: true` anchors the
              // newest line at the bottom and grows up; older lines clip
              // off the top. `NeverScrollableScrollPhysics` makes the
              // view truly fixed — no drag, no wheel, no jumps.
              MouseRegion(
                cursor: SystemMouseCursors.text,
                child: ListView.builder(
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  itemCount: lines.length,
                  itemBuilder: (context, i) {
                    final lineIndex = lines.length - 1 - i;
                    return TerminalLine(
                      line: lines[lineIndex],
                      lineIndex: lineIndex,
                      selection: selection,
                      fontSize: fontSize,
                      onCommandTap: _sendLinkCommand,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
