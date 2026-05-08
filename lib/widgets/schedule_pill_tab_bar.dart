import 'package:flutter/material.dart';

import '/widgets/top_pill_tabs.dart';

/// Schedule tabs with shared Option B styling.
const _scheduleTabs = <TopPillTabItem>[
  TopPillTabItem(icon: Icons.calendar_today_rounded, label: 'Today'),
  TopPillTabItem(icon: Icons.fitness_center_rounded, label: 'Training'),
  TopPillTabItem(icon: Icons.event_available_rounded, label: 'Events'),
  TopPillTabItem(icon: Icons.support_agent_rounded, label: 'Coach'),
];

/// Four equal-width pill tabs with icons — modern replacement for plain segmented control.
class SchedulePillTabBar extends StatelessWidget {
  const SchedulePillTabBar({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TopPillTabs(
      items: _scheduleTabs,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      height: 56,
      borderRadius: 22,
      innerRadius: 17,
      itemSpacing: 4,
      labelFontSize: 11.5,
    );
  }
}
