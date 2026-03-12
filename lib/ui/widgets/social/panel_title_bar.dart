import 'package:flutter/material.dart';

/// Title bar of a social panel with drag handle, title, and action buttons.
class PanelTitleBar extends StatelessWidget {
  final String title;
  final bool isDocked;
  final bool isTabbed;
  final VoidCallback onClose;
  final VoidCallback? onDock;
  final VoidCallback? onUndock;
  final VoidCallback? onCombineTabs;
  final VoidCallback? onSeparateTabs;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const PanelTitleBar({
    super.key,
    required this.title,
    required this.isDocked,
    required this.isTabbed,
    required this.onClose,
    this.onDock,
    this.onUndock,
    this.onCombineTabs,
    this.onSeparateTabs,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return GestureDetector(
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: primary.withAlpha(40),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        ),
        child: Row(
          children: [
            Icon(Icons.drag_indicator, size: 16, color: primary.withAlpha(120)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Combine/separate tabs button.
            if (isTabbed && onSeparateTabs != null)
              _TitleButton(
                icon: Icons.tab_unselected,
                tooltip: 'Separate windows',
                onPressed: onSeparateTabs!,
              )
            else if (!isTabbed && onCombineTabs != null)
              _TitleButton(
                icon: Icons.tab,
                tooltip: 'Combine into tabs',
                onPressed: onCombineTabs!,
              ),

            // Dock/undock button.
            if (isDocked && onUndock != null)
              _TitleButton(
                icon: Icons.open_in_new,
                tooltip: 'Undock',
                onPressed: onUndock!,
              )
            else if (!isDocked && onDock != null)
              _TitleButton(
                icon: Icons.push_pin_outlined,
                tooltip: 'Dock to side',
                onPressed: onDock!,
              ),

            // Close button.
            _TitleButton(
              icon: Icons.close,
              tooltip: 'Close',
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _TitleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        icon: Icon(icon, size: 14),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        color: Theme.of(context).colorScheme.primary.withAlpha(180),
      ),
    );
  }
}
