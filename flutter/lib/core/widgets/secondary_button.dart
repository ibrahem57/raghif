import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Outlined, not filled — a solid second button would compete visually with
/// the screen's one primary action (UI_SPEC.md PurchaseScreen treatment).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.text, this.onPressed});

  final String text;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        foregroundColor: AppColors.accent,
        textStyle: AppTypography.labelLarge.copyWith(color: AppColors.accent),
      ),
      child: Text(text),
    );
  }
}
