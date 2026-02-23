import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/layout_constants.dart';
import '../../../shared/widgets/icon_button_small.dart';

class PanelTabBar extends StatelessWidget {
  const PanelTabBar({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
  });

  final String activeTab;
  final void Function(String tab) onTabSelected;

  static const _tabs = [
    ('problems', 'Problems'),
    ('output', 'Output'),
    ('debug_console', 'Debug Console'),
    ('terminal', 'Terminal'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: LayoutConstants.panelTabBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          ..._tabs.map(
            (tab) => _PanelTab(
              id: tab.$1,
              label: tab.$2,
              isActive: activeTab == tab.$1,
              onTap: () => onTabSelected(tab.$1),
            ),
          ),
          const Spacer(),
          IconButtonSmall(
            icon: Icons.add,
            onPressed: () {},
            tooltip: 'New Terminal',
          ),
          const SizedBox(width: 4),
          IconButtonSmall(
            icon: Icons.keyboard_arrow_down,
            onPressed: () {},
            tooltip: 'Toggle Panel',
          ),
          const SizedBox(width: 4),
          IconButtonSmall(
            icon: Icons.close,
            onPressed: () {},
            tooltip: 'Close Panel',
          ),
        ],
      ),
    );
  }
}

class _PanelTab extends StatefulWidget {
  const _PanelTab({
    required this.id,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String id;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_PanelTab> createState() => _PanelTabState();
}

class _PanelTabState extends State<_PanelTab> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          margin: const EdgeInsets.symmetric(vertical: 4),
          height: LayoutConstants.panelTabBarHeight - 8,
          decoration: BoxDecoration(
            color:
                _isHovering && !widget.isActive
                    ? AppColors.hoverHighlight
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(
              LayoutConstants.borderRadiusSmall,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.label,
                style:
                    widget.isActive
                        ? AppTextStyles.panelTabActive
                        : AppTextStyles.panelTabInactive,
              ),
              const SizedBox(height: 2),
              Container(
                height: 2,
                width: 24,
                decoration: BoxDecoration(
                  color:
                      widget.isActive ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
