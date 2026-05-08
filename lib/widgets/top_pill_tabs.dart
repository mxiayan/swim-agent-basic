import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/theme/lavender_indigo_tokens.dart';
import '/theme/swim_design_tokens.dart';

class TopPillTabItem {
  const TopPillTabItem({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

/// Shared pill tabs used across Schedule / Meets / Agent.
class TopPillTabs extends StatelessWidget {
  const TopPillTabs({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.height = 46,
    this.borderRadius = 14,
    this.innerRadius = 11,
    this.itemSpacing = 6,
    this.labelFontSize = 12.5,
  });

  final List<TopPillTabItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double height;
  final double borderRadius;
  final double innerRadius;
  final double itemSpacing;
  final double labelFontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: SwimDsTokens.borderSoft),
        boxShadow: SwimDsTokens.cardShadowSoft,
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) SizedBox(width: itemSpacing),
            Expanded(
              child: _TopPillTabButton(
                item: items[i],
                selected: selectedIndex == i,
                borderRadius: innerRadius,
                labelFontSize: labelFontSize,
                onTap: () => onChanged(i),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopPillTabButton extends StatelessWidget {
  const _TopPillTabButton({
    required this.item,
    required this.selected,
    required this.borderRadius,
    required this.labelFontSize,
    required this.onTap,
  });

  final TopPillTabItem item;
  final bool selected;
  final double borderRadius;
  final double labelFontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : SwimDsTokens.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: selected ? LavenderIndigoTokens.heroGradient : null,
            color: selected ? null : Colors.transparent,
            boxShadow: selected ? LavenderIndigoTokens.shadowSm : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
