import 'package:flutter/material.dart';

/// Title bar of a social panel with drag handle, title, and action buttons.
class PanelTitleBar extends StatelessWidget {
  final String title;
  final bool isDocked;
  final bool isTabbed;
  final bool hasUnread;
  final VoidCallback onClose;
  final VoidCallback? onDock;
  final VoidCallback? onUndock;
  final VoidCallback? onCombineTabs;
  final VoidCallback? onSeparateTabs;
  final VoidCallback? onCycleTimestampMode;
  final IconData? timestampModeIcon;
  final String? timestampModeLabel;
  final String? timestampModeTooltip;
  final GestureDragStartCallback onPanStart;
  final GestureDragUpdateCallback onPanUpdate;
  final GestureDragEndCallback onPanEnd;

  const PanelTitleBar({
    super.key,
    required this.title,
    required this.isDocked,
    required this.isTabbed,
    this.hasUnread = false,
    required this.onClose,
    this.onDock,
    this.onUndock,
    this.onCombineTabs,
    this.onSeparateTabs,
    this.onCycleTimestampMode,
    this.timestampModeIcon,
    this.timestampModeLabel,
    this.timestampModeTooltip,
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
          color: hasUnread
              ? Colors.amber.withAlpha(50)
              : primary.withAlpha(40),
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

            // Combine/separate tabs – prominent pill button.
            if (isTabbed && onSeparateTabs != null)
              _LabeledPill(
                icon: Icons.splitscreen,
                label: 'Separate',
                onPressed: onSeparateTabs!,
              )
            else if (!isTabbed && onCombineTabs != null)
              _LabeledPill(
                icon: Icons.join_full,
                label: 'Combine',
                onPressed: onCombineTabs!,
              ),

            // Trifold: timestamp display mode (show → showOnHover → hide).
            if (onCycleTimestampMode != null && timestampModeIcon != null)
              _LabeledPill(
                icon: timestampModeIcon!,
                label: timestampModeLabel ?? 'Time',
                tooltip: timestampModeTooltip ?? 'Cycle timestamp display',
                onPressed: onCycleTimestampMode!,
              ),

            // Dock/undock button.
            if (isDocked && onUndock != null)
              _LabeledPill(
                icon: Icons.open_in_new,
                label: 'Undock',
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

/// A visually prominent pill-shaped button with an icon and a short text
/// label. Used in the panel title bar for actions that warrant more
/// affordance than a plain icon button — Combine/Separate, Undock, and the
/// timestamp-mode trifold.
class _LabeledPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? tooltip;
  final VoidCallback onPressed;

  const _LabeledPill({
    required this.icon,
    required this.label,
    this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    Widget pill = Material(
      color: primary.withAlpha(35),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (tooltip != null) {
      pill = Tooltip(message: tooltip!, child: pill);
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: pill,
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
