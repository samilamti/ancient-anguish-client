import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social_panel_state.dart';
import 'settings_provider.dart';

/// Whether the current platform is desktop (not web).
bool isDesktopPlatform() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Whether social windows are enabled (settings toggle only; the width-based
/// `!isMobile` guard in [HomeScreen] already prevents them on small screens).
final socialWindowsEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.socialWindowsEnabled;
});

/// Panel layout state.
final socialPanelProvider =
    NotifierProvider<SocialPanelNotifier, SocialWindowsState>(
        SocialPanelNotifier.new);

/// Manages panel visibility, position, docking, and tab mode.
class SocialPanelNotifier extends Notifier<SocialWindowsState> {
  @override
  SocialWindowsState build() => const SocialWindowsState();

  // ── Visibility ──

  void toggleChatVisible() {
    state = state.copyWith(
      chatPanel: state.chatPanel.copyWith(visible: !state.chatPanel.visible),
    );
  }

  void toggleTellsVisible() {
    state = state.copyWith(
      tellsPanel:
          state.tellsPanel.copyWith(visible: !state.tellsPanel.visible),
    );
  }

  void togglePartyVisible() {
    state = state.copyWith(
      partyPanel:
          state.partyPanel.copyWith(visible: !state.partyPanel.visible),
    );
  }

  void showChat() {
    state = state.copyWith(
      chatPanel: state.chatPanel.copyWith(visible: true),
    );
  }

  void showTells() {
    state = state.copyWith(
      tellsPanel: state.tellsPanel.copyWith(visible: true),
    );
  }

  void showParty() {
    state = state.copyWith(
      partyPanel: state.partyPanel.copyWith(visible: true),
    );
  }

  void toggleNotesVisible() {
    state = state.copyWith(
      notesPanel:
          state.notesPanel.copyWith(visible: !state.notesPanel.visible),
    );
  }

  void showNotes() {
    state = state.copyWith(
      notesPanel: state.notesPanel.copyWith(visible: true),
    );
  }

  // ── Floating position ──

  void updateChatPosition(double x, double y) {
    state = state.copyWith(
      chatPanel: state.chatPanel.copyWith(x: x, y: y),
    );
  }

  void updateTellsPosition(double x, double y) {
    state = state.copyWith(
      tellsPanel: state.tellsPanel.copyWith(x: x, y: y),
    );
  }

  void updatePartyPosition(double x, double y) {
    state = state.copyWith(
      partyPanel: state.partyPanel.copyWith(x: x, y: y),
    );
  }

  void updateChatSize(double width, double height) {
    state = state.copyWith(
      chatPanel: state.chatPanel.copyWith(width: width, height: height),
    );
  }

  void updateTellsSize(double width, double height) {
    state = state.copyWith(
      tellsPanel: state.tellsPanel.copyWith(width: width, height: height),
    );
  }

  void updatePartySize(double width, double height) {
    state = state.copyWith(
      partyPanel: state.partyPanel.copyWith(width: width, height: height),
    );
  }

  void updateNotesPosition(double x, double y) {
    state = state.copyWith(
      notesPanel: state.notesPanel.copyWith(x: x, y: y),
    );
  }

  void updateNotesSize(double width, double height) {
    state = state.copyWith(
      notesPanel: state.notesPanel.copyWith(width: width, height: height),
    );
  }

  // ── Docking ──

  void dockChat(DockSide side) {
    state = state.copyWith(
      chatPanel: state.chatPanel.copyWith(dockSide: () => side),
    );
  }

  void undockChat() {
    state = state.copyWith(
      chatPanel: state.chatPanel.copyWith(dockSide: () => null),
    );
  }

  void dockTells(DockSide side) {
    state = state.copyWith(
      tellsPanel: state.tellsPanel.copyWith(dockSide: () => side),
    );
  }

  void undockTells() {
    state = state.copyWith(
      tellsPanel: state.tellsPanel.copyWith(dockSide: () => null),
    );
  }

  void dockParty(DockSide side) {
    state = state.copyWith(
      partyPanel: state.partyPanel.copyWith(dockSide: () => side),
    );
  }

  void undockParty() {
    state = state.copyWith(
      partyPanel: state.partyPanel.copyWith(dockSide: () => null),
    );
  }

  void dockNotes(DockSide side) {
    state = state.copyWith(
      notesPanel: state.notesPanel.copyWith(dockSide: () => side),
    );
  }

  void undockNotes() {
    state = state.copyWith(
      notesPanel: state.notesPanel.copyWith(dockSide: () => null),
    );
  }

  // ── Tab mode ──

  void combineIntoTabs() {
    state = state.copyWith(
      tabMode: PanelTabMode.tabbed,
      chatPanel: state.chatPanel.copyWith(visible: true),
      tellsPanel: state.tellsPanel.copyWith(visible: true),
      partyPanel: state.partyPanel.copyWith(visible: true),
      notesPanel: state.notesPanel.copyWith(visible: true),
    );
  }

  void separateFromTabs() {
    state = state.copyWith(tabMode: PanelTabMode.separate);
  }

  void setActiveTab(int index) {
    state = state.copyWith(
      activeTab: index,
      chatHasUnread: index == 0 ? false : state.chatHasUnread,
      tellsHasUnread: index == 1 ? false : state.tellsHasUnread,
      partyHasUnread: index == 2 ? false : state.partyHasUnread,
    );
  }

  // ── Unread indicators ──

  void markChatUnread() {
    if (!state.chatHasUnread) {
      state = state.copyWith(chatHasUnread: true);
    }
  }

  void markTellsUnread() {
    if (!state.tellsHasUnread) {
      state = state.copyWith(tellsHasUnread: true);
    }
  }

  void markPartyUnread() {
    if (!state.partyHasUnread) {
      state = state.copyWith(partyHasUnread: true);
    }
  }

  void clearChatUnread() {
    if (state.chatHasUnread) {
      state = state.copyWith(chatHasUnread: false);
    }
  }

  void clearTellsUnread() {
    if (state.tellsHasUnread) {
      state = state.copyWith(tellsHasUnread: false);
    }
  }

  void clearPartyUnread() {
    if (state.partyHasUnread) {
      state = state.copyWith(partyHasUnread: false);
    }
  }

  // ── Reset ──

  void reset() => state = const SocialWindowsState();
}
