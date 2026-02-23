import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/layout_constants.dart';
import '../widgets/global_search_box.dart';
import 'package:bewy/features/title_bar/widgets/menu_bar_widget.dart';
import '../widgets/window_controls.dart';

class TitleBar extends ConsumerWidget {
  const TitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final searchWidth = (constraints.maxWidth * 0.34).clamp(260.0, 620.0);
        final horizontalPad =
            constraints.maxWidth >= 1200
                ? 300.0
                : constraints.maxWidth >= 900
                ? 220.0
                : 120.0;
        return Container(
          height: LayoutConstants.titleBarHeight,
          decoration: BoxDecoration(
            color: AppColors.titleBarBackground,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.only(left: 12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  // Logo + title — draggable
                  _DraggableArea(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/logo.png',
                          width: 14,
                          height: 14,
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                  // Menu bar — NOT inside any drag/double-tap GestureDetector
                  const MenuBarWidget(),
                  const Expanded(
                    child: _DraggableArea(child: SizedBox.expand()),
                  ),
                  const WindowControls(),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPad),
                child: Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    child: SizedBox(
                      width: searchWidth.toDouble(),
                      child: const GlobalSearchBox(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DraggableArea extends StatelessWidget {
  const _DraggableArea({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      child: child,
    );
  }
}
