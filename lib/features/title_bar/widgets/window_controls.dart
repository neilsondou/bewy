import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../../core/services/app_exit_service.dart';
import '../../../core/theme/app_colors.dart';

class WindowControls extends StatelessWidget {
  const WindowControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          icon: Icons.remove,
          onPressed: () => windowManager.minimize(),
        ),
        _WindowButton(
          icon: Icons.crop_square_outlined,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        _WindowButton(
          icon: Icons.close,
          onPressed: () => AppExitService.requestClose(),
          isClose: true,
        ),
      ],
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 36,
          height: 30,
          decoration: BoxDecoration(
            color:
                _isHovering
                    ? (widget.isClose
                        ? AppColors.error.withValues(alpha: 0.8)
                        : AppColors.hoverHighlight)
                    : Colors.transparent,
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color:
                _isHovering && widget.isClose
                    ? Colors.white
                    : AppColors.secondaryForeground,
          ),
        ),
      ),
    );
  }
}
