import 'package:flutter/material.dart';
import 'package:bewy/core/editor/re_editor_compat.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class FindPanel extends StatelessWidget implements PreferredSizeWidget {
  const FindPanel({
    super.key,
    required this.controller,
    required this.readOnly,
  });

  final CodeFindController controller;
  final bool readOnly;

  @override
  Size get preferredSize {
    final isReplace = controller.value?.replaceMode == true;
    return Size.fromHeight(isReplace ? 64 : 34);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CodeFindValue?>(
      valueListenable: controller,
      builder: (context, value, _) {
        final isReplace = value?.replaceMode == true;
        final matchCount = value?.result?.matches.length ?? 0;
        final matchIndex = value?.result?.index ?? -1;
        final matchText =
            matchCount > 0 ? '${matchIndex + 1} of $matchCount' : 'No results';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Find row
              Row(
                children: [
                  if (!readOnly)
                    _IconBtn(
                      icon: isReplace ? Icons.expand_less : Icons.expand_more,
                      tooltip: 'Toggle Replace',
                      onTap: () => controller.toggleMode(),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _FindInput(
                      controller: controller.findInputController,
                      focusNode: controller.findInputFocusNode,
                      hintText: 'Find',
                      onSubmitted: (_) {
                        controller.nextMatch();
                        controller.findInputFocusNode.requestFocus();
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 70,
                    child: Text(
                      value?.result != null ? matchText : '',
                      style: AppTextStyles.uiSmall.copyWith(
                        color: AppColors.mutedForeground,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  _ToggleBtn(
                    label: 'Aa',
                    tooltip: 'Match Case',
                    isActive: value?.option.caseSensitive == true,
                    onTap: () => controller.toggleCaseSensitive(),
                  ),
                  _ToggleBtn(
                    label: '.*',
                    tooltip: 'Use Regex',
                    isActive: value?.option.regex == true,
                    onTap: () => controller.toggleRegex(),
                  ),
                  const SizedBox(width: 4),
                  _IconBtn(
                    icon: Icons.keyboard_arrow_up,
                    tooltip: 'Previous Match',
                    onTap: () => controller.previousMatch(),
                  ),
                  _IconBtn(
                    icon: Icons.keyboard_arrow_down,
                    tooltip: 'Next Match',
                    onTap: () => controller.nextMatch(),
                  ),
                  const SizedBox(width: 4),
                  _IconBtn(
                    icon: Icons.close,
                    tooltip: 'Close',
                    onTap: () => controller.close(),
                  ),
                ],
              ),
              // Replace row
              if (isReplace && !readOnly) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const SizedBox(width: 28),
                    Expanded(
                      child: _FindInput(
                        controller: controller.replaceInputController,
                        focusNode: controller.replaceInputFocusNode,
                        hintText: 'Replace',
                        onSubmitted: (_) {
                          controller.replaceMatch();
                          controller.replaceInputFocusNode.requestFocus();
                        },
                      ),
                    ),
                    const SizedBox(width: 78),
                    _IconBtn(
                      icon: Icons.find_replace,
                      tooltip: 'Replace',
                      onTap: () => controller.replaceMatch(),
                    ),
                    _IconBtn(
                      icon: Icons.done_all,
                      tooltip: 'Replace All',
                      onTap: () => controller.replaceAllMatches(),
                    ),
                    const SizedBox(width: 28),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _IconBtn extends StatefulWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _hovering ? AppColors.hoverHighlight : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              widget.icon,
              size: 14,
              color: AppColors.secondaryForeground,
            ),
          ),
        ),
      ),
    );
  }
}

class _ToggleBtn extends StatefulWidget {
  const _ToggleBtn({
    required this.label,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });
  final String label;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_ToggleBtn> createState() => _ToggleBtnState();
}

class _ToggleBtnState extends State<_ToggleBtn> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color:
                  widget.isActive
                      ? AppColors.listActiveSelectionBackground
                      : _hovering
                      ? AppColors.hoverHighlight
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                widget.label,
                style: AppTextStyles.uiSmall.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      widget.isActive
                          ? AppColors.foreground
                          : AppColors.secondaryForeground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FindInput extends StatelessWidget {
  const _FindInput({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: AppTextStyles.uiSmall.copyWith(fontSize: 12),
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: AppTextStyles.uiSmall.copyWith(
              color: AppColors.mutedForeground,
              fontSize: 12,
            ),
            filled: true,
            fillColor: AppColors.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            isDense: true,
            border: InputBorder.none,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.border, width: 0.5),
              borderRadius: BorderRadius.zero,
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent, width: 1),
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      ),
    );
  }
}
