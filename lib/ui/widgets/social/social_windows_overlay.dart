import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/social_panel_state.dart';
import '../../../providers/social_panel_provider.dart';
import 'social_panel.dart';

/// Overlay widget that positions floating/docked social panels in the Stack.
class SocialWindowsOverlay extends ConsumerWidget {
  const SocialWindowsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(socialWindowsEnabledProvider);
    if (!enabled) return const SizedBox.shrink();

    final panelState = ref.watch(socialPanelProvider);
    final screenSize = MediaQuery.of(context).size;
    final widgets = <Widget>[];

    if (panelState.tabMode == PanelTabMode.tabbed &&
        panelState.chatPanel.visible &&
        panelState.tellsPanel.visible &&
        panelState.partyPanel.visible &&
        panelState.notesPanel.visible) {
      // Single tabbed panel — use chat panel's position/size.
      widgets.add(
        _positionPanel(
          panelState.chatPanel,
          screenSize,
          const SocialPanel(panelType: SocialPanelType.tabbed),
        ),
      );
    } else {
      // Separate panels.
      if (panelState.chatPanel.visible) {
        widgets.add(
          _positionPanel(
            panelState.chatPanel,
            screenSize,
            const SocialPanel(panelType: SocialPanelType.chat),
          ),
        );
      }
      if (panelState.tellsPanel.visible) {
        widgets.add(
          _positionPanel(
            panelState.tellsPanel,
            screenSize,
            const SocialPanel(panelType: SocialPanelType.tells),
          ),
        );
      }
      if (panelState.partyPanel.visible) {
        widgets.add(
          _positionPanel(
            panelState.partyPanel,
            screenSize,
            const SocialPanel(panelType: SocialPanelType.party),
          ),
        );
      }
      if (panelState.notesPanel.visible) {
        widgets.add(
          _positionPanel(
            panelState.notesPanel,
            screenSize,
            const SocialPanel(panelType: SocialPanelType.notes),
          ),
        );
      }
    }

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Stack(children: widgets);
  }

  Widget _positionPanel(
    SocialPanelState ps,
    Size screenSize,
    Widget child,
  ) {
    if (ps.isDocked) {
      return _buildDockedPanel(ps, screenSize, child);
    }
    return Positioned(
      left: ps.x,
      top: ps.y,
      width: ps.width,
      height: ps.height,
      child: child,
    );
  }

  Widget _buildDockedPanel(
    SocialPanelState ps,
    Size screenSize,
    Widget child,
  ) {
    final left = ps.dockSide == DockSide.left ? 0.0 : null;
    final right = ps.dockSide == DockSide.right ? 0.0 : null;

    return Positioned(
      left: left,
      right: right,
      top: 0,
      bottom: 0,
      width: ps.width,
      child: child,
    );
  }
}
