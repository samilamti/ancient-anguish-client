import 'package:flutter/material.dart';

import '../../../../models/sheet.dart';
import 'sheet_frame.dart';

/// Renders a shop's `list` output as a price table.
///
/// The MUD pads item names with dot leaders to reach a fixed cost column, which
/// is a typesetting trick for a fixed-width terminal and pure noise once the
/// client can lay out a real table. Prices are right-aligned and the count only
/// appears when there is more than one, so "2x" carries information instead of
/// every row starting with "1".
///
/// Tapping the header re-sorts cheapest-first; the MUD's own order is the
/// default because that is what the player asked for.
class ShopListSheetWidget extends StatelessWidget {
  final ShopListSheet sheet;
  final bool sortedByCost;
  final VoidCallback onToggleSort;

  const ShopListSheetWidget({
    super.key,
    required this.sheet,
    required this.sortedByCost,
    required this.onToggleSort,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = sortedByCost ? sheet.byCost : sheet.items;

    return SheetFrame(
      icon: Icons.sell,
      title: 'For sale',
      trailingLabel: [
        '${sheet.items.length} items',
        if (sheet.isTruncated) 'of ${sheet.total}',
        if (sortedByCost) 'by price',
      ].join(' · '),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleSort,
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Icon(
                  sortedByCost ? Icons.sort : Icons.sort_by_alpha,
                  size: 13,
                  color: scheme.onSurface.withAlpha(130),
                ),
                const SizedBox(width: 5),
                Text(
                  sortedByCost ? 'Cheapest first' : 'Shop order',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    color: scheme.onSurface.withAlpha(130),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          for (final item in items) _ShopRow(item: item),
          if (sheet.isTruncated) ...[
            const SizedBox(height: 5),
            Text(
              'Showing ${sheet.shown} of ${sheet.total} — the shop had more to '
              'say.',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: scheme.onSurface.withAlpha(130),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShopRow extends StatelessWidget {
  final ShopItem item;

  const _ShopRow({required this.item});

  /// Groups thousands so a four-digit price is readable at a glance — the MUD
  /// prints a bare `1075`, which is harder to compare down a column than 1,075.
  static String _money(int amount) {
    final digits = amount.toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: item.count > 1
                ? Text(
                    '${item.count}x',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 10.5,
                      color: scheme.secondary,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: Text(
              item.name,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11.5,
                color: scheme.onSurface.withAlpha(230),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money(item.cost),
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11.5,
              color: const Color(0xFFD4A057),
            ),
          ),
        ],
      ),
    );
  }
}
