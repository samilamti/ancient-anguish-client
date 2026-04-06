import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/social_panel_state.dart';
import '../../../providers/social_panel_provider.dart';
import 'panel_title_bar.dart';
import 'social_input_bar.dart';
import 'social_message_list.dart';

/// The type of panel to display.
enum SocialPanelType { chat, tells, party, tabbed }

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
    } else {
      notifier.updateChatSize(newWidth, newHeight);
    }
  }

  void _onResizeEnd(DragEndDetails details) {
    _resizeStartSize = null;
    _resizeStartPos = null;
  }

  // ── Actions ──

  void _close() {
    final notifier = ref.read(socialPanelProvider.notifier);
    if (widget.panelType == SocialPanelType.tabbed) {
      notifier.separateFromTabs();
      notifier.toggleChatVisible();
      notifier.toggleTellsVisible();
      notifier.togglePartyVisible();
    } else if (widget.panelType == SocialPanelType.chat) {
      notifier.toggleChatVisible();
    } else if (widget.panelType == SocialPanelType.tells) {
      notifier.toggleTellsVisible();
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
    } else {
      notifier.undockChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelState = ref.watch(socialPanelProvider);
    final panel = _getPanel(panelState);

    return Material(
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
              _buildTabbedTitleBar(panelState)
            else
              PanelTitleBar(
                title: switch (widget.panelType) {
                  SocialPanelType.chat => 'Chat',
                  SocialPanelType.tells => 'Tells',
                  SocialPanelType.party => 'Party',
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
  }

  bool _canCombine(SocialWindowsState state) {
    // Can combine if at least 2 panels are visible.
    final visibleCount = [
      state.chatPanel.visible,
      state.tellsPanel.visible,
      state.partyPanel.visible,
    ].where((v) => v).length;
    return visibleCount >= 2;
  }

  Widget _buildTabbedTitleBar(SocialWindowsState panelState) {
    final titles = ['Chat', 'Tells', 'Party'];
    return PanelTitleBar(
      title: titles[panelState.activeTab.clamp(0, 2)],
      isDocked: panelState.chatPanel.isDocked,
      isTabbed: true,
      onClose: _close,
      onDock: panelState.chatPanel.isFloating ? _dockRight : null,
      onUndock: panelState.chatPanel.isDocked ? _undock : null,
      onSeparateTabs: () =>
          ref.read(socialPanelProvider.notifier).separateFromTabs(),
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
            label: 'Chat',
            active: panelState.activeTab == 0,
            hasUnread: panelState.chatHasUnread,
            onTap: () =>
                ref.read(socialPanelProvider.notifier).setActiveTab(0),
          ),
          _TabButton(
            label: 'Tells',
            active: panelState.activeTab == 1,
            hasUnread: panelState.tellsHasUnread,
            onTap: () =>
                ref.read(socialPanelProvider.notifier).setActiveTab(1),
          ),
          _TabButton(
            label: 'Party',
            active: panelState.activeTab == 2,
            hasUnread: panelState.partyHasUnread,
            onTap: () =>
                ref.read(socialPanelProvider.notifier).setActiveTab(2),
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
    if (widget.panelType == SocialPanelType.tabbed) {
      final idx = panelState.activeTab.clamp(0, 2);
      return SocialMessageList(
        key: ValueKey(_tabListTypes[idx]),
        type: _tabListTypes[idx],
      );
    }
    return SocialMessageList(
      type: switch (widget.panelType) {
        SocialPanelType.chat => SocialListType.chat,
        SocialPanelType.tells => SocialListType.tells,
        SocialPanelType.party => SocialListType.party,
        _ => SocialListType.chat,
      },
    );
  }

  Widget _buildInputBar(SocialWindowsState panelState) {
    if (widget.panelType == SocialPanelType.tabbed) {
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
    with SingleTickerProviderStateMixin {
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
