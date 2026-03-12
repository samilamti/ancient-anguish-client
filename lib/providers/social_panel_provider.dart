import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social_panel_state.dart';
import 'settings_provider.dart';

/// Whether the current platform is desktop.
bool isDesktopPlatform() {
  return defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

/// Whether social windows are enabled (desktop only + settings toggle).
final socialWindowsEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return settings.socialWindowsEnabled && isDesktopPlatform();
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

  // ── Tab mode ──

  void combineIntoTabs() {
    state = state.copyWith(
      tabMode: PanelTabMode.tabbed,
      chatPanel: state.chatPanel.copyWith(visible: true),
      tellsPanel: state.tellsPanel.copyWith(visible: true),
    );
  }

  void separateFromTabs() {
    state = state.copyWith(tabMode: PanelTabMode.separate);
  }

  void setActiveTab(int index) {
    state = state.copyWith(activeTab: index);
  }

  // ── Reset ──

  void reset() => state = const SocialWindowsState();
}
