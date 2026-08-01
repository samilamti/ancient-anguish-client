import 'package:flutter/material.dart';

/// The shared chrome every sheet sits in, so `skills`, `score` and a shop
/// listing read as one family rather than three unrelated widgets that happen
/// to appear in the same place.
///
/// Deliberately unlike the parchment card used for framed MUD text: that one
/// imitates in-world paper (a sign, a letter), whereas a sheet is the *client*
/// presenting the player's own data, so it uses the app's surface colours and
/// stays visually part of the UI.
class SheetFrame extends StatelessWidget {
  final IconData icon;
  final String title;

  /// Shown to the right of the title — a count, a total, a page indicator.
  final String? trailingLabel;

  /// When non-null the header becomes a button and gets a chevron.
  final VoidCallback? onToggleExpanded;
  final bool expanded;

  /// Shrinks the panel to the width its content needs instead of filling the
  /// terminal. For a list of short item names, a full-width panel leaves the
  /// prices stranded on the far side of an empty gutter.
  final bool fitContent;

  final Widget child;

  const SheetFrame({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailingLabel,
    this.onToggleExpanded,
    this.expanded = false,
    this.fitContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final header = Row(
      children: [
        Icon(icon, size: 15, color: scheme.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: scheme.primary,
            ),
          ),
        ),
        if (trailingLabel != null)
          Text(
            trailingLabel!,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              color: scheme.onSurface.withAlpha(140),
            ),
          ),
        if (onToggleExpanded != null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: scheme.primary.withAlpha(200),
            ),
          ),
      ],
    );

    final panel = Container(
      decoration: BoxDecoration(
        // A raised surface rather than the page colour: in dark mode a shadow
        // alone carries no elevation against a near-black background, so the
        // sheet needs its own fill and a border to read as a panel at all.
        color: scheme.surface.withAlpha(235),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.primary.withAlpha(55)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (onToggleExpanded == null)
            header
          else
            InkWell(
              onTap: onToggleExpanded,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: header,
              ),
            ),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      // `IntrinsicWidth` rather than a `Row` with a spacer: the panel's own
      // children (the header, and rows with a flexible name column) all want to
      // fill whatever width they are handed, so only asking them what they
      // *need* shrinks the panel. Bounded by the terminal width as usual, so a
      // long item name still wraps instead of overflowing.
      child: fitContent
          ? Align(
              alignment: AlignmentDirectional.centerStart,
              child: IntrinsicWidth(child: panel),
            )
          : panel,
    );
  }
}

/// One `label  value` row, used by several sheets. The label column is a fixed
/// fraction of the width so rows line up without the fixed-width padding the
/// MUD used — which is the whole point of rendering these ourselves.
class SheetRow extends StatelessWidget {
  final String label;
  final String value;

  /// Draws the value in the accent colour, for the fields that matter most.
  final bool emphasised;

  /// Shown after the value — a `+ 600` / `- 3000` change since last time.
  final Widget? trailing;

  const SheetRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasised = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: scheme.onSurface.withAlpha(135),
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11.5,
                fontWeight: emphasised ? FontWeight.bold : FontWeight.normal,
                color: emphasised
                    ? scheme.primary
                    : scheme.onSurface.withAlpha(225),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
