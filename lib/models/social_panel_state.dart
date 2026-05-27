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
    this.width = 480,
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
  final SocialPanelState partyPanel;
  final SocialPanelState notesPanel;
  final PanelTabMode tabMode;
  final int activeTab; // 0=chat, 1=tells, 2=party, 3=notes (when tabbed)
  final bool chatHasUnread;
  final bool tellsHasUnread;
  final bool partyHasUnread;
  // Ephemeral mobile-only "is the SWC overlay currently shown?" flag.
  // Desktop ignores this — visibility there is driven by panel.visible.
  // On mobile the overlay covers the terminal fullscreen, so we need an
  // explicit open/close gate independent of the per-panel visibility
  // booleans (which default to true and persist across runs).
  final bool mobileOpen;

  const SocialWindowsState({
    this.chatPanel = const SocialPanelState(
      visible: true,
      dockSide: DockSide.right,
    ),
    this.tellsPanel = const SocialPanelState(
      visible: true,
      x: 460,
    ),
    this.partyPanel = const SocialPanelState(
      visible: true,
      x: 820,
    ),
    this.notesPanel = const SocialPanelState(
      visible: true,
      x: 1180,
    ),
    this.tabMode = PanelTabMode.tabbed,
    this.activeTab = 0,
    this.chatHasUnread = false,
    this.tellsHasUnread = false,
    this.partyHasUnread = false,
    this.mobileOpen = false,
  });

  SocialWindowsState copyWith({
    SocialPanelState? chatPanel,
    SocialPanelState? tellsPanel,
    SocialPanelState? partyPanel,
    SocialPanelState? notesPanel,
    PanelTabMode? tabMode,
    int? activeTab,
    bool? chatHasUnread,
    bool? tellsHasUnread,
    bool? partyHasUnread,
    bool? mobileOpen,
  }) {
    return SocialWindowsState(
      chatPanel: chatPanel ?? this.chatPanel,
      tellsPanel: tellsPanel ?? this.tellsPanel,
      partyPanel: partyPanel ?? this.partyPanel,
      notesPanel: notesPanel ?? this.notesPanel,
      tabMode: tabMode ?? this.tabMode,
      activeTab: activeTab ?? this.activeTab,
      chatHasUnread: chatHasUnread ?? this.chatHasUnread,
      tellsHasUnread: tellsHasUnread ?? this.tellsHasUnread,
      partyHasUnread: partyHasUnread ?? this.partyHasUnread,
      mobileOpen: mobileOpen ?? this.mobileOpen,
    );
  }
}
