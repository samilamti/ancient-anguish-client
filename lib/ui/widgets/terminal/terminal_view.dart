import 'dart:async';

import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../models/terminal_block.dart';
import '../../../protocol/ansi/styled_span.dart';
import '../../../providers/background_image_provider.dart';
import '../../../providers/connection_provider.dart'
    show terminalBufferProvider, inputFocusProvider;
import '../../../providers/settings_provider.dart';
import '../../../providers/terminal_block_provider.dart';
import '../../../services/platform/file_utils.dart';
import 'block_action_bar.dart';
import 'terminal_selection.dart';
import 'terminal_selection_controller.dart';

/// The main terminal output widget.
///
/// Displays the scrollback buffer as a scrollable list of styled text lines.
/// Uses [ListView.builder] for efficient rendering of large buffers.
/// Implements custom text selection with inverse-video highlighting.
class TerminalView extends ConsumerStatefulWidget {
  const TerminalView({super.key});

  @override
  ConsumerState<TerminalView> createState() => _TerminalViewState();
}

class _TerminalViewState extends ConsumerState<TerminalView> {
  final ScrollController _scrollController = ScrollController();
  final TerminalSelectionController _selectionController =
      TerminalSelectionController();
  final FocusNode _focusNode = FocusNode();
  bool _autoScroll = true;

  // Pointer-based tap detection (replaces GestureDetector to avoid
  // competing with SelectionArea in the gesture arena).
  int _tapCount = 0;
  DateTime _lastPointerDown = DateTime(0);
  Offset _lastPointerDownPosition = Offset.zero;
  bool _pointerMoved = false;
  bool _primaryButtonDown = false;
  Timer? _tapTimer;
  Timer? _autoScrollTimer;

  static const double _tapSlopSquared = 18.0 * 18.0;
  static const Duration _doubleTapTimeout = Duration(milliseconds: 300);
  static const double _blockSeparatorHeight = 8.0;

  // Monospace font measurements (recomputed when font size changes).
  double _charWidth = 0;
  double _lineHeight = 0;
  bool _fontMeasured = false;
  double _measuredFontSize = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _autoScrollTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
    // Line height = font metrics + vertical padding (0.5 top + 0.5 bottom).
    _lineHeight = painter.height + 1.0;
    painter.dispose();
    _fontMeasured = true;
    _measuredFontSize = fontSize;
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
  // Hit-testing: convert pointer position → TerminalPosition
  // ---------------------------------------------------------------------------

  TerminalPosition? _hitTest(Offset localPosition, List<StyledLine> lines) {
    if (_charWidth == 0 || _lineHeight == 0 || lines.isEmpty) return null;

    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    // Account for ListView padding (horizontal: 8, vertical: 4).
    final adjustedY = localPosition.dy + scrollOffset - 4.0;
    final adjustedX = localPosition.dx - 8.0;

    final lineIndex = (adjustedY / _lineHeight).floor();
    if (lineIndex < 0) return const TerminalPosition(0, 0);
    if (lineIndex >= lines.length) {
      final last = lines.length - 1;
      return TerminalPosition(last, lines[last].plainText.length);
    }

    final lineLength = lines[lineIndex].plainText.length;
    final column = (adjustedX / _charWidth).round().clamp(0, lineLength);
    return TerminalPosition(lineIndex, column);
  }

  /// Hit-test for block mode: walks blocks to account for separator heights.
  TerminalPosition? _hitTestBlocks(
      Offset localPosition, List<TerminalBlock> blocks, List<StyledLine> lines) {
    if (_charWidth == 0 || _lineHeight == 0 || blocks.isEmpty) return null;

    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final adjustedY = localPosition.dy + scrollOffset - 4.0;
    final adjustedX = localPosition.dx - 8.0;

    // Walk blocks to find which block and line the Y coordinate falls in.
    var cumulativeY = 0.0;
    for (final block in blocks) {
      final blockHeight = block.lineCount * _lineHeight;
      if (adjustedY < cumulativeY + blockHeight) {
        // Within this block.
        final localLineIndex =
            ((adjustedY - cumulativeY) / _lineHeight).floor().clamp(0, block.lineCount - 1);
        final globalIndex = block.startLineIndex + localLineIndex;
        if (globalIndex >= lines.length) break;
        final lineLength = lines[globalIndex].plainText.length;
        final column = (adjustedX / _charWidth).round().clamp(0, lineLength);
        return TerminalPosition(globalIndex, column);
      }
      cumulativeY += blockHeight + _blockSeparatorHeight;
    }

    // Below all blocks — clamp to last line.
    if (lines.isNotEmpty) {
      final last = lines.length - 1;
      return TerminalPosition(last, lines[last].plainText.length);
    }
    return null;
  }

  /// Dispatches to flat or block hit-test based on current mode.
  TerminalPosition? _hitTestAuto(Offset localPosition) {
    final lines = ref.read(terminalBufferProvider);
    if (ref.read(settingsProvider).blockModeEnabled) {
      final blocks = ref.read(terminalBlocksProvider);
      return _hitTestBlocks(localPosition, blocks, lines);
    }
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
      // Shift+click extends selection.
      if (_selectionController.updateSelection(pos)) setState(() {});
    } else {
      // Start a new selection anchor point (won't display until pointer moves).
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

    // Auto-scroll when dragging near edges.
    _handleAutoScroll(localPos);
  }

  void _onPointerUp(PointerUpEvent event) {
    _primaryButtonDown = false;
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;

    // Auto-copy when user finishes a drag-to-select gesture.
    if (_selectionController.hasSelection && _pointerMoved) {
      // Ensure selection is non-trivial (anchor != focus).
      final sel = _selectionController.selection!;
      if (sel.anchor != sel.focus) {
        _selectionController.copyToClipboard(ref.read(terminalBufferProvider));
        // Focus the terminal so Ctrl+C works for subsequent copies.
        _focusNode.requestFocus();
        return;
      }
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

  void _handleAutoScroll(Offset localPosition) {
    const edgeThreshold = 40.0;
    const scrollSpeed = 8.0;

    final viewportHeight =
        (context.findRenderObject() as RenderBox?)?.size.height ?? 0;

    if (localPosition.dy < edgeThreshold) {
      _autoScrollTimer ??= Timer.periodic(
        const Duration(milliseconds: 16),
        (_) {
          if (!_scrollController.hasClients) return;
          _scrollController.jumpTo(
            (_scrollController.offset - scrollSpeed)
                .clamp(0, _scrollController.position.maxScrollExtent),
          );
          // Update selection at new scroll position.
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final pos = _hitTestAuto(Offset(localPosition.dx, 0));
          if (pos != null && _selectionController.updateSelection(pos)) {
            setState(() {});
          }
        },
      );
    } else if (localPosition.dy > viewportHeight - edgeThreshold) {
      _autoScrollTimer ??= Timer.periodic(
        const Duration(milliseconds: 16),
        (_) {
          if (!_scrollController.hasClients) return;
          _scrollController.jumpTo(
            (_scrollController.offset + scrollSpeed)
                .clamp(0, _scrollController.position.maxScrollExtent),
          );
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final pos =
              _hitTestAuto(Offset(localPosition.dx, viewportHeight));
          if (pos != null && _selectionController.updateSelection(pos)) {
            setState(() {});
          }
        },
      );
    } else {
      _autoScrollTimer?.cancel();
      _autoScrollTimer = null;
    }
  }

  void _resetTapState() {
    _tapCount = 0;
    _tapTimer?.cancel();
    _tapTimer = null;
  }

  void _handleSingleTap() {
    final sel = _selectionController.selection;
    // Only treat as "deselect" if there's a non-trivial selection
    // (anchor != focus). A zero-width selection from pointer-down is not real.
    if (sel != null && sel.anchor != sel.focus) {
      _selectionController.clearSelection();
      setState(() {});
      return;
    }
    _selectionController.clearSelection();
    ref.read(inputFocusProvider).requestFocus();
  }

  void _handleDoubleTap() {
    setState(() {
      _autoScroll = true;
    });
    _scrollToBottom();
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
        if (hitPos != null)
          const PopupMenuItem(value: 'copy_line', child: Text('Copy Line')),
        const PopupMenuItem(value: 'select_all', child: Text('Select All')),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'copy':
          _selectionController.copyToClipboard(lines);
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
    final blockMode = settings.blockModeEnabled;
    _measureFont(fontSize);
    final lines = ref.watch(terminalBufferProvider);
    final blocks = blockMode ? ref.watch(terminalBlocksProvider) : <TerminalBlock>[];
    final selection = _selectionController.selection;
    final bgImagePath = ref.watch(backgroundImageProvider);

    // Auto-scroll when new lines arrive.
    ref.listen<List<StyledLine>>(terminalBufferProvider, (previous, next) {
      if (_autoScroll && next.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    });

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

              // Terminal output.
              MouseRegion(
                cursor: SystemMouseCursors.text,
                child: blockMode
                    ? ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        cacheExtent: 2000,
                        itemCount: blocks.length,
                        itemBuilder: (context, blockIndex) {
                          return _TerminalBlockWidget(
                            key: ValueKey(blocks[blockIndex].id),
                            block: blocks[blockIndex],
                            selection: selection,
                            fontSize: fontSize,
                            separatorHeight: _blockSeparatorHeight,
                          );
                        },
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        cacheExtent: 2000,
                        itemCount: lines.length,
                        itemBuilder: (context, index) {
                          return _TerminalLine(
                            line: lines[index],
                            lineIndex: index,
                            selection: selection,
                            fontSize: fontSize,
                          );
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
      ),
    );
  }
}

/// A block of grouped terminal output lines with hover actions.
class _TerminalBlockWidget extends StatefulWidget {
  final TerminalBlock block;
  final TerminalSelection? selection;
  final double fontSize;
  final double separatorHeight;

  const _TerminalBlockWidget({
    super.key,
    required this.block,
    required this.selection,
    required this.fontSize,
    required this.separatorHeight,
  });

  @override
  State<_TerminalBlockWidget> createState() => _TerminalBlockWidgetState();
}

class _TerminalBlockWidgetState extends State<_TerminalBlockWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.block.isEmpty) return SizedBox(height: widget.separatorHeight);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        margin: EdgeInsets.only(bottom: widget.separatorHeight),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Theme.of(context).dividerColor.withAlpha(40),
              width: 0.5,
            ),
          ),
        ),
        child: Stack(
          children: [
            // Block lines.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.block.lineCount; i++)
                  _TerminalLine(
                    line: widget.block.lines[i],
                    lineIndex: widget.block.startLineIndex + i,
                    selection: widget.selection,
                    fontSize: widget.fontSize,
                  ),
              ],
            ),
            // Hover action bar.
            if (_isHovered)
              Positioned(
                top: 2,
                right: 2,
                child: BlockActionBar(block: widget.block),
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
  final int lineIndex;
  final TerminalSelection? selection;
  final double fontSize;

  const _TerminalLine({
    required this.line,
    required this.lineIndex,
    this.selection,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (line.spans.isEmpty) {
      // Empty line – render as a space so it takes up space consistently.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 0.5),
        child: RichText(
          text: TextSpan(
            text: ' ',
            style: TextStyle(
              fontFamily: TerminalDefaults.fontFamily,
              fontSize: fontSize,
            ),
          ),
        ),
      );
    }

    final range = selection?.selectedRangeForLine(
      lineIndex,
      line.plainText.length,
    );

    final textSpan = range != null
        ? line.toSelectedTextSpan(
            fontFamily: TerminalDefaults.fontFamily,
            fontSize: fontSize,
            startCol: range.startCol,
            endCol: range.endCol,
          )
        : line.toTextSpan(
            fontFamily: TerminalDefaults.fontFamily,
            fontSize: fontSize,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: RichText(
        text: textSpan,
        softWrap: true,
      ),
    );
  }
}
