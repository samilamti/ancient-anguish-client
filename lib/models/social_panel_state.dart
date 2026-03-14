/// Where the panel is docked, or null if floating.
enum DockSide { left, right }

/// How panels are arranged when combined.
enum PanelTabMode { separate, tabbed }

/// Layout state for a single social panel.
class SocialPanelState {
  final bool visible;
  final DockSide? dockSide;
  final double x;
  final double y;
  final double width;
  final double height;

  const SocialPanelState({
    this.visible = false,
    this.dockSide,
    this.x = 100,
    this.y = 100,
    this.width = 340,
    this.height = 400,
  });

  bool get isFloating => dockSide == null;
  bool get isDocked => dockSide != null;

  SocialPanelState copyWith({
    bool? visible,
    DockSide? Function()? dockSide,
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return SocialPanelState(
      visible: visible ?? this.visible,
      dockSide: dockSide != null ? dockSide() : this.dockSide,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// Combined state for the social windows system.
class SocialWindowsState {
  final SocialPanelState chatPanel;
  final SocialPanelState tellsPanel;
  final PanelTabMode tabMode;
  final int activeTab; // 0=chat, 1=tells (when tabbed)
  final bool chatHasUnread;
  final bool tellsHasUnread;

  const SocialWindowsState({
    this.chatPanel = const SocialPanelState(
      visible: true,
      dockSide: DockSide.right,
    ),
    this.tellsPanel = const SocialPanelState(
      visible: true,
      dockSide: DockSide.right,
      x: 460,
    ),
    this.tabMode = PanelTabMode.tabbed,
    this.activeTab = 0,
    this.chatHasUnread = false,
    this.tellsHasUnread = false,
  });

  SocialWindowsState copyWith({
    SocialPanelState? chatPanel,
    SocialPanelState? tellsPanel,
    PanelTabMode? tabMode,
    int? activeTab,
    bool? chatHasUnread,
    bool? tellsHasUnread,
  }) {
    return SocialWindowsState(
      chatPanel: chatPanel ?? this.chatPanel,
      tellsPanel: tellsPanel ?? this.tellsPanel,
      tabMode: tabMode ?? this.tabMode,
      activeTab: activeTab ?? this.activeTab,
      chatHasUnread: chatHasUnread ?? this.chatHasUnread,
      tellsHasUnread: tellsHasUnread ?? this.tellsHasUnread,
    );
  }
}
