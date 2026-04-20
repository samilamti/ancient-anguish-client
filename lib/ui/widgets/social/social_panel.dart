import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/social_panel_state.dart';
import '../../../models/timestamp_mode.dart';
import '../../../providers/notes_content_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/social_input_focus_provider.dart';
import '../../../providers/social_panel_provider.dart';
import 'panel_title_bar.dart';
import 'social_input_bar.dart';
import 'social_message_list.dart';

/// The type of panel to display.
enum SocialPanelType { chat, tells, party, notes, tabbed }

/// A floating or docked panel for displaying social messages.
///
/// Supports dragging, resizing, docking to viewport edges, and tabbed mode.
class SocialPanel extends ConsumerStatefulWidget {
  final SocialPanelType panelType;

  const SocialPanel({super.key, required this.panelType});

  @override
  ConsumerState<SocialPanel> createState() => _SocialPanelState();
}

class _SocialPanelState extends ConsumerState<SocialPanel> {
  static const double _minWidth = 250;
  static const double _minHeight = 200;

  Offset? _dragStartLocal;
  Size? _resizeStartSize;
  Offset? _resizeStartPos;

  SocialPanelState _getPanel(SocialWindowsState ps) {
    return switch (widget.panelType) {
      SocialPanelType.tells => ps.tellsPanel,
      SocialPanelType.party => ps.partyPanel,
      SocialPanelType.notes => ps.notesPanel,
      _ => ps.chatPanel, // chat + tabbed use chatPanel for position
    };
  }

  // ── Drag handling ──

  void _onPanStart(DragStartDetails details) {
    _dragStartLocal = details.localPosition;
    final panelState = ref.read(socialPanelProvider);
    final notifier = ref.read(socialPanelProvider.notifier);
    if (widget.panelType == SocialPanelType.chat &&
        panelState.chatPanel.isDocked) {
      notifier.undockChat();
    } else if (widget.panelType == SocialPanelType.tells &&
        panelState.tellsPanel.isDocked) {
      notifier.undockTells();
    } else if (widget.panelType == SocialPanelType.party &&
        panelState.partyPanel.isDocked) {
      notifier.undockParty();
    } else if (widget.panelType == SocialPanelType.notes &&
        panelState.notesPanel.isDocked) {
      notifier.undockNotes();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStartLocal == null) return;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final parentBox =
        renderBox.parent is RenderBox ? renderBox.parent! as RenderBox : null;
    if (parentBox == null) return;

    final globalPos = details.globalPosition;
    final parentLocal = parentBox.globalToLocal(globalPos);

    final newX = parentLocal.dx - _dragStartLocal!.dx;
    final newY = parentLocal.dy - _dragStartLocal!.dy;

    final notifier = ref.read(socialPanelProvider.notifier);
    if (widget.panelType == SocialPanelType.tells) {
      notifier.updateTellsPosition(newX.clamp(0, double.infinity), newY.clamp(0, double.infinity));
    } else if (widget.panelType == SocialPanelType.party) {
      notifier.updatePartyPosition(newX.clamp(0, double.infinity), newY.clamp(0, double.infinity));
    } else if (widget.panelType == SocialPanelType.notes) {
      notifier.updateNotesPosition(newX.clamp(0, double.infinity), newY.clamp(0, double.infinity));
    } else {
      notifier.updateChatPosition(newX.clamp(0, double.infinity), newY.clamp(0, double.infinity));
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _dragStartLocal = null;
  }

  // ── Resize handling ──

  void _onResizeStart(DragStartDetails details) {
    final panelState = ref.read(socialPanelProvider);
    final panel = _getPanel(panelState);
    _resizeStartSize = Size(panel.width, panel.height);
    _resizeStartPos = details.globalPosition;
  }

  void _onResizeUpdate(DragUpdateDetails details) {
    if (_resizeStartSize == null || _resizeStartPos == null) return;

    final delta = details.globalPosition - _resizeStartPos!;
    final newWidth = (_resizeStartSize!.width + delta.dx).clamp(_minWidth, double.infinity);
    final newHeight = (_resizeStartSize!.height + delta.dy).clamp(_minHeight, double.infinity);

    final notifier = ref.read(socialPanelProvider.notifier);
    if (widget.panelType == SocialPanelType.tells) {
      notifier.updateTellsSize(newWidth, newHeight);
    } else if (widget.panelType == SocialPanelType.party) {
      notifier.updatePartySize(newWidth, newHeight);
    } else if (widget.panelType == SocialPanelType.notes) {
      notifier.updateNotesSize(newWidth, newHeight);
    } else {
      notifier.updateChatSize(newWidth, newHeight);
    }
  }

  void _onResizeEnd(DragEndDetails details) {
    _resizeStartSize = null;
    _resizeStartPos = null;
  }

  // ── Docked-edge width resize ──
  //
  // When the panel is docked to an edge, expose a thin vertical drag strip
  // on the inward-facing edge. Dragging it adjusts the panel's width so the
  // user can grow or shrink the docked cluster without first undocking.

  double? _edgeStartWidth;
  Offset? _edgeStartPos;

  void _onEdgeResizeStart(DragStartDetails details) {
    final panelState = ref.read(socialPanelProvider);
    final panel = _getPanel(panelState);
    _edgeStartWidth = panel.width;
    _edgeStartPos = details.globalPosition;
  }

  void _onEdgeResizeUpdate(DragUpdateDetails details, DockSide side) {
    if (_edgeStartWidth == null || _edgeStartPos == null) return;
    final dx = details.globalPosition.dx - _edgeStartPos!.dx;
    // Right-docked: dragging the LEFT edge leftwards (-dx) grows the panel.
    // Left-docked:  dragging the RIGHT edge rightwards (+dx) grows the panel.
    final delta = side == DockSide.right ? -dx : dx;
    final panelState = ref.read(socialPanelProvider);
    final panel = _getPanel(panelState);
    final newWidth =
        (_edgeStartWidth! + delta).clamp(_minWidth, double.infinity);

    final notifier = ref.read(socialPanelProvider.notifier);
    if (widget.panelType == SocialPanelType.tells) {
      notifier.updateTellsSize(newWidth, panel.height);
    } else if (widget.panelType == SocialPanelType.party) {
      notifier.updatePartySize(newWidth, panel.height);
    } else if (widget.panelType == SocialPanelType.notes) {
      notifier.updateNotesSize(newWidth, panel.height);
    } else {
      notifier.updateChatSize(newWidth, panel.height);
    }
  }

  void _onEdgeResizeEnd(DragEndDetails details) {
    _edgeStartWidth = null;
    _edgeStartPos = null;
  }

  // ── Actions ──

  void _close() {
    final notifier = ref.read(socialPanelProvider.notifier);
    if (widget.panelType == SocialPanelType.tabbed) {
      notifier.separateFromTabs();
      notifier.toggleChatVisible();
      notifier.toggleTellsVisible();
      notifier.togglePartyVisible();
      notifier.toggleNotesVisible();
    } else if (widget.panelType == SocialPanelType.chat) {
      notifier.toggleChatVisible();
    } else if (widget.panelType == SocialPanelType.tells) {
      notifier.toggleTellsVisible();
    } else if (widget.panelType == SocialPanelType.notes) {
      notifier.toggleNotesVisible();
    } else {
      notifier.togglePartyVisible();
    }
  }

  void _dockRight() {
    final notifier = ref.read(socialPanelProvider.notifier);
    if (widget.panelType == SocialPanelType.tells) {
      notifier.dockTells(DockSide.right);
    } else if (widget.panelType == SocialPanelType.party) {
      notifier.dockParty(DockSide.right);
    } else if (widget.panelType == SocialPanelType.notes) {
      notifier.dockNotes(DockSide.right);
    } else {
      notifier.dockChat(DockSide.right);
    }
  }

  void _undock() {
    final notifier = ref.read(socialPanelProvider.notifier);
    if (widget.panelType == SocialPanelType.tells) {
      notifier.undockTells();
    } else if (widget.panelType == SocialPanelType.party) {
      notifier.undockParty();
    } else if (widget.panelType == SocialPanelType.notes) {
      notifier.undockNotes();
    } else {
      notifier.undockChat();
    }
  }

  // ── Timestamp trifold helpers ──

  /// Whether the current view shows social messages (i.e. should render the
  /// timestamp toggle). Notes has no timestamps so it's omitted.
  bool _showsTimestampToggle(SocialWindowsState panelState) {
    if (widget.panelType == SocialPanelType.notes) return false;
    if (widget.panelType == SocialPanelType.tabbed) {
      return panelState.activeTab != 3;
    }
    return true;
  }

  IconData _timestampIcon(TimestampMode mode) {
    return switch (mode) {
      TimestampMode.show => Icons.schedule,
      TimestampMode.showOnHover => Icons.mouse_outlined,
      TimestampMode.hide => Icons.timer_off_outlined,
    };
  }

  String _timestampLabel(TimestampMode mode) {
    return switch (mode) {
      TimestampMode.show => 'Time: On',
      TimestampMode.showOnHover => 'Time: Hover',
      TimestampMode.hide => 'Time: Off',
    };
  }

  String _timestampTooltip(TimestampMode mode) {
    return switch (mode) {
      TimestampMode.show => 'Timestamps: shown (click for on-hover)',
      TimestampMode.showOnHover => 'Timestamps: on hover (click to hide)',
      TimestampMode.hide => 'Timestamps: hidden (click to show)',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelState = ref.watch(socialPanelProvider);
    final panel = _getPanel(panelState);
    final timestampMode = ref.watch(
      settingsProvider.select((s) => s.timestampMode),
    );
    final showTimestampToggle = _showsTimestampToggle(panelState);

    final body = Material(
      elevation: panel.isDocked ? 4 : 8,
      borderRadius: BorderRadius.circular(8),
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          minWidth: _minWidth,
          minHeight: _minHeight,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.primary.withAlpha(60),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // Title bar.
            if (widget.panelType == SocialPanelType.tabbed)
              _buildTabbedTitleBar(panelState, timestampMode,
                  showTimestampToggle)
            else
              PanelTitleBar(
                title: switch (widget.panelType) {
                  SocialPanelType.chat => 'Chat',
                  SocialPanelType.tells => 'Tells',
                  SocialPanelType.party => 'Party',
                  SocialPanelType.notes => 'Notes',
                  _ => '',
                },
                isDocked: panel.isDocked,
                isTabbed: false,
                hasUnread: switch (widget.panelType) {
                  SocialPanelType.chat => panelState.chatHasUnread,
                  SocialPanelType.tells => panelState.tellsHasUnread,
                  SocialPanelType.party => panelState.partyHasUnread,
                  _ => false,
                },
                onClose: _close,
                onDock: panel.isFloating ? _dockRight : null,
                onUndock: panel.isDocked ? _undock : null,
                onCombineTabs: _canCombine(panelState)
                    ? () => ref
                        .read(socialPanelProvider.notifier)
                        .combineIntoTabs()
                    : null,
                timestampModeIcon: showTimestampToggle
                    ? _timestampIcon(timestampMode)
                    : null,
                timestampModeLabel: showTimestampToggle
                    ? _timestampLabel(timestampMode)
                    : null,
                timestampModeTooltip: showTimestampToggle
                    ? _timestampTooltip(timestampMode)
                    : null,
                onCycleTimestampMode: showTimestampToggle
                    ? () => ref
                        .read(settingsProvider.notifier)
                        .cycleTimestampMode()
                    : null,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
              ),

            // Tab bar (tabbed mode).
            if (widget.panelType == SocialPanelType.tabbed)
              _buildTabBar(panelState),

            // Message list.
            Expanded(
              child: _buildMessageList(panelState),
            ),

            // Input bar.
            _buildInputBar(panelState),

            // Resize handle.
            if (panel.isFloating) _buildResizeHandle(theme),
          ],
        ),
      ),
    );

    if (panel.isDocked && panel.dockSide != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: body),
          _buildDockedEdgeHandle(theme, panel.dockSide!),
        ],
      );
    }
    return body;
  }

  /// Thin vertical drag strip at the docked edge for width resizing.
  ///
  /// Positioned at the panel's inward-facing edge: the LEFT edge when docked
  /// right, the RIGHT edge when docked left. Full panel height; the handle's
  /// hit zone is 8 px wide with a centered 2 px visual line.
  Widget _buildDockedEdgeHandle(ThemeData theme, DockSide side) {
    const handleWidth = 8.0;
    return Positioned(
      top: 0,
      bottom: 0,
      left: side == DockSide.right ? 0 : null,
      right: side == DockSide.left ? 0 : null,
      width: handleWidth,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onEdgeResizeStart,
          onHorizontalDragUpdate: (d) => _onEdgeResizeUpdate(d, side),
          onHorizontalDragEnd: _onEdgeResizeEnd,
          child: Center(
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(90),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _canCombine(SocialWindowsState state) {
    // Can combine if at least 2 panels are visible.
    final visibleCount = [
      state.chatPanel.visible,
      state.tellsPanel.visible,
      state.partyPanel.visible,
      state.notesPanel.visible,
    ].where((v) => v).length;
    return visibleCount >= 2;
  }

  Widget _buildTabbedTitleBar(
    SocialWindowsState panelState,
    TimestampMode timestampMode,
    bool showTimestampToggle,
  ) {
    final titles = ['Chat', 'Tells', 'Party', 'Notes'];
    return PanelTitleBar(
      title: titles[panelState.activeTab.clamp(0, 3)],
      isDocked: panelState.chatPanel.isDocked,
      isTabbed: true,
      onClose: _close,
      onDock: panelState.chatPanel.isFloating ? _dockRight : null,
      onUndock: panelState.chatPanel.isDocked ? _undock : null,
      onSeparateTabs: () =>
          ref.read(socialPanelProvider.notifier).separateFromTabs(),
      timestampModeIcon:
          showTimestampToggle ? _timestampIcon(timestampMode) : null,
      timestampModeLabel:
          showTimestampToggle ? _timestampLabel(timestampMode) : null,
      timestampModeTooltip:
          showTimestampToggle ? _timestampTooltip(timestampMode) : null,
      onCycleTimestampMode: showTimestampToggle
          ? () => ref.read(settingsProvider.notifier).cycleTimestampMode()
          : null,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
    );
  }

  Widget _buildTabBar(SocialWindowsState panelState) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      height: 28,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: primary.withAlpha(30)),
        ),
      ),
      child: Row(
        children: [
          _TabButton(
            label: '💬 Chat',
            active: panelState.activeTab == 0,
            hasUnread: panelState.chatHasUnread,
            onTap: () =>
                ref.read(socialPanelProvider.notifier).setActiveTab(0),
          ),
          _TabButton(
            label: '✉️ Tells',
            active: panelState.activeTab == 1,
            hasUnread: panelState.tellsHasUnread,
            onTap: () =>
                ref.read(socialPanelProvider.notifier).setActiveTab(1),
          ),
          _TabButton(
            label: '🎉 Party',
            active: panelState.activeTab == 2,
            hasUnread: panelState.partyHasUnread,
            onTap: () =>
                ref.read(socialPanelProvider.notifier).setActiveTab(2),
          ),
          _TabButton(
            label: '📝 Notes',
            active: panelState.activeTab == 3,
            onTap: () =>
                ref.read(socialPanelProvider.notifier).setActiveTab(3),
          ),
        ],
      ),
    );
  }

  static const _tabListTypes = [
    SocialListType.chat,
    SocialListType.tells,
    SocialListType.party,
  ];

  Widget _buildMessageList(SocialWindowsState panelState) {
    if (widget.panelType == SocialPanelType.notes) {
      return const _NotesBody();
    }
    if (widget.panelType == SocialPanelType.tabbed) {
      if (panelState.activeTab == 3) {
        return const _NotesBody();
      }
      final idx = panelState.activeTab.clamp(0, 2);
      final type = _tabListTypes[idx];
      return _FocusOnTap(
        type: type,
        child: SocialMessageList(key: ValueKey(type), type: type),
      );
    }
    final type = switch (widget.panelType) {
      SocialPanelType.chat => SocialListType.chat,
      SocialPanelType.tells => SocialListType.tells,
      SocialPanelType.party => SocialListType.party,
      _ => SocialListType.chat,
    };
    return _FocusOnTap(
      type: type,
      child: SocialMessageList(type: type),
    );
  }

  Widget _buildInputBar(SocialWindowsState panelState) {
    if (widget.panelType == SocialPanelType.notes) {
      return const SizedBox.shrink();
    }
    if (widget.panelType == SocialPanelType.tabbed) {
      if (panelState.activeTab == 3) {
        return const SizedBox.shrink();
      }
      final idx = panelState.activeTab.clamp(0, 2);
      return SocialInputBar(type: _tabListTypes[idx]);
    }
    return SocialInputBar(
      type: switch (widget.panelType) {
        SocialPanelType.chat => SocialListType.chat,
        SocialPanelType.tells => SocialListType.tells,
        SocialPanelType.party => SocialListType.party,
        _ => SocialListType.chat,
      },
    );
  }

  Widget _buildResizeHandle(ThemeData theme) {
    return GestureDetector(
      onPanStart: _onResizeStart,
      onPanUpdate: _onResizeUpdate,
      onPanEnd: _onResizeEnd,
      child: Align(
        alignment: Alignment.bottomRight,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeDownRight,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.drag_handle,
              size: 12,
              color: theme.colorScheme.primary.withAlpha(60),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatefulWidget {
  final String label;
  final bool active;
  final bool hasUnread;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    this.hasUnread = false,
    required this.onTap,
  });

  @override
  State<_TabButton> createState() => _TabButtonState();
}

class _TabButtonState extends State<_TabButton>
    with TickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _syncPulse();
  }

  @override
  void didUpdateWidget(_TabButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasUnread != oldWidget.hasUnread ||
        widget.active != oldWidget.active) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    final shouldPulse = widget.hasUnread && !widget.active;
    if (shouldPulse && _pulseController == null) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      )..repeat(reverse: true);
    } else if (!shouldPulse && _pulseController != null) {
      _pulseController!.dispose();
      _pulseController = null;
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final showUnread = widget.hasUnread && !widget.active;

    return Expanded(
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.active
                ? primary.withAlpha(25)
                : showUnread
                    ? Colors.amber.withAlpha(50)
                    : null,
            border: Border(
              bottom: BorderSide(
                color: widget.active
                    ? primary
                    : showUnread
                        ? Colors.amber
                        : Colors.transparent,
                width: widget.active ? 3 : 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: widget.active ? 12 : 11,
                  fontWeight: widget.active ? FontWeight.bold : FontWeight.normal,
                  color: widget.active
                      ? primary
                      : showUnread
                          ? Colors.amber
                          : primary.withAlpha(100),
                ),
              ),
              if (showUnread && _pulseController != null) ...[
                const SizedBox(width: 4),
                AnimatedBuilder(
                  animation: _pulseController!,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.4 + 0.6 * _pulseController!.value,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent tap target that forwards a bare tap in the message area to the
/// shared input focus node for the given [type]. Scroll gestures still pass
/// through to the underlying list; only a discrete tap triggers focus.
class _FocusOnTap extends ConsumerWidget {
  final SocialListType type;
  final Widget child;

  const _FocusOnTap({required this.type, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        final node = ref.read(socialInputFocusProvider)[type];
        if (node != null && !node.hasFocus) node.requestFocus();
      },
      child: child,
    );
  }
}

/// Free-form notes editor. Content is loaded from / saved to `Notes.md`
/// through [notesContentProvider].
class _NotesBody extends ConsumerStatefulWidget {
  const _NotesBody();

  @override
  ConsumerState<_NotesBody> createState() => _NotesBodyState();
}

class _NotesBodyState extends ConsumerState<_NotesBody> {
  late final TextEditingController _controller;

  /// Focus node owned by [notesFocusProvider] so external code (e.g. the
  /// Cmd+4 shortcut) can request focus without reaching in here.
  FocusNode get _focusNode => ref.read(notesFocusProvider);

  /// Cached notifier reference — needed in [dispose] where `ref` is no
  /// longer safe to touch (the element is already unmounted at that point).
  late final NotesContentNotifier _contentNotifier;

  @override
  void initState() {
    super.initState();
    _contentNotifier = ref.read(notesContentProvider.notifier);
    _controller = TextEditingController(text: ref.read(notesContentProvider));
    ref.listenManual<String>(notesContentProvider, (prev, next) {
      // Only overwrite the controller when the external value differs —
      // avoids cursor jumps when our own onChanged round-trips through state.
      if (next != _controller.text) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
      }
    });
  }

  @override
  void dispose() {
    // Flush any pending debounced save before the widget goes away. Use
    // the cached notifier — `ref.read` is unsafe post-unmount.
    _contentNotifier.flush();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: (v) =>
            ref.read(notesContentProvider.notifier).updateContent(v),
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 13,
          color: theme.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: 'Jot down notes, quest steps, coordinates…',
          hintStyle: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 13,
            color: theme.colorScheme.onSurface.withAlpha(100),
          ),
        ),
      ),
    );
  }
}
