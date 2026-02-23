import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class OutputPanel extends StatelessWidget {
  const OutputPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panelBase,
      padding: const EdgeInsets.all(8),
      child: Text(
        'No output yet.',
        style: AppTextStyles.terminal.copyWith(
          color: AppColors.secondaryForeground,
        ),
      ),
    );
  }
}
