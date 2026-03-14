import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/social_panel_state.dart';
import '../../../providers/social_panel_provider.dart';
import 'panel_title_bar.dart';
import 'social_input_bar.dart';
import 'social_message_list.dart';

/// The type of panel to display.
enum SocialPanelType { chat, tells, tabbed }

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
  static const double _dockSnapThreshold = 40.0;
  static const double _minWidth = 250;
  static const double _minHeight = 200;

  Offset? _dragStartLocal;
  Size? _resizeStartSize;
  Offset? _resizeStartPos;

  // ── Drag handling ──

  void _onPanStart(DragStartDetails details) {
    _dragStartLocal = details.localPosition;
    // If docked, undock first.
    final panelState = ref.read(socialPanelProvider);
    if (widget.panelType == SocialPanelType.chat &&
        panelState.chatPanel.isDocked) {
      ref.read(socialPanelProvider.notifier).undockChat();
    } else if (widget.panelType == SocialPanelType.tells &&
        panelState.tellsPanel.isDocked) {
      ref.read(socialPanelProvider.notifier).undockTells();
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
    if (widget.panelType == SocialPanelType.chat ||
        widget.panelType == SocialPanelType.tabbed) {
      notifier.updateChatPosition(newX.clamp(0, double.infinity), newY.clamp(0, double.infinity));
    } else {
      notifier.updateTellsPosition(newX.clamp(0, double.infinity), newY.clamp(0, double.infinity));
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _dragStartLocal = null;

    final screenSize = MediaQuery.of(context).size;
    final panelState = ref.read(socialPanelProvider);
    final notifier = ref.read(socialPanelProvider.notifier);

    final panel = widget.panelType == SocialPanelType.tells
        ? panelState.tellsPanel
        : panelState.chatPanel;

    // Check left edge snap.
    if (panel.x < _dockSnapThreshold) {
      if (widget.panelType == SocialPanelType.tells) {
        notifier.dockTells(DockSide.left);
      } else {
        notifier.dockChat(DockSide.left);
      }
      return;
    }

    // Check right edge snap.
    if (panel.x + panel.width > screenSize.width - _dockSnapThreshold) {
      if (widget.panelType == SocialPanelType.tells) {
        notifier.dockTells(DockSide.right);
      } else {
        notifier.dockChat(DockSide.right);
      }
    }
  }

  // ── Resize handling ──

  void _onResizeStart(DragStartDetails details) {
    final panelState = ref.read(socialPanelProvider);
    final panel = widget.panelType == SocialPanelType.tells
        ? panelState.tellsPanel
        : panelState.chatPanel;
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
    } else if (widget.panelType == SocialPanelType.chat) {
      notifier.toggleChatVisible();
    } else {
      notifier.toggleTellsVisible();
    }
  }

  void _dockRight() {
    final notifier = ref.read(socialPanelProvider.notifier);
    if (widget.panelType == SocialPanelType.tells) {
      notifier.dockTells(DockSide.right);
    } else {
      notifier.dockChat(DockSide.right);
    }
  }

  void _undock() {
    final notifier = ref.read(socialPanelProvider.notifier);
    if (widget.panelType == SocialPanelType.tells) {
      notifier.undockTells();
    } else {
      notifier.undockChat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelState = ref.watch(socialPanelProvider);
    final panel = widget.panelType == SocialPanelType.tells
        ? panelState.tellsPanel
        : panelState.chatPanel;

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
                title: widget.panelType == SocialPanelType.chat
                    ? 'Chat'
                    : 'Tells',
                isDocked: panel.isDocked,
                isTabbed: false,
                hasUnread: widget.panelType == SocialPanelType.chat
                    ? panelState.chatHasUnread
                    : panelState.tellsHasUnread,
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
    return state.chatPanel.visible && state.tellsPanel.visible;
  }

  Widget _buildTabbedTitleBar(SocialWindowsState panelState) {
    return PanelTitleBar(
      title: panelState.activeTab == 0 ? 'Chat' : 'Tells',
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
        ],
      ),
    );
  }

  Widget _buildMessageList(SocialWindowsState panelState) {
    if (widget.panelType == SocialPanelType.tabbed) {
      return panelState.activeTab == 0
          ? const SocialMessageList(type: SocialListType.chat)
          : const SocialMessageList(type: SocialListType.tells);
    }
    return SocialMessageList(
      type: widget.panelType == SocialPanelType.chat
          ? SocialListType.chat
          : SocialListType.tells,
    );
  }

  Widget _buildInputBar(SocialWindowsState panelState) {
    if (widget.panelType == SocialPanelType.tabbed) {
      return panelState.activeTab == 0
          ? const SocialInputBar(type: SocialListType.chat)
          : const SocialInputBar(type: SocialListType.tells);
    }
    return SocialInputBar(
      type: widget.panelType == SocialPanelType.chat
          ? SocialListType.chat
          : SocialListType.tells,
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

class _TabButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final showUnread = hasUnread && !active;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: showUnread ? Colors.amber.withAlpha(30) : null,
            border: Border(
              bottom: BorderSide(
                color: active
                    ? primary
                    : showUnread
                        ? Colors.amber
                        : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active
                      ? primary
                      : showUnread
                          ? Colors.amber
                          : primary.withAlpha(100),
                ),
              ),
              if (showUnread) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
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
