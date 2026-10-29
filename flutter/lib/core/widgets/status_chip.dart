import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum StatusTone { success, warning, danger, neutral }

class _ToneColors {
  const _ToneColors(this.container, this.content);
  final Color container;
  final Color content;
}

_ToneColors _toneColors(StatusTone tone) {
  switch (tone) {
    case StatusTone.success:
      return const _ToneColors(
        AppColors.successContainer,
        AppColors.onSuccessContainer,
      );
    case StatusTone.warning:
      return const _ToneColors(
        AppColors.warningContainer,
        AppColors.onWarningContainer,
      );
    case StatusTone.danger:
      return const _ToneColors(
        AppColors.dangerContainer,
        AppColors.onDangerContainer,
      );
    case StatusTone.neutral:
      return const _ToneColors(
        AppColors.neutralContainer,
        AppColors.textSecondary,
      );
  }
}

/// Status pairs a color with an icon/label — color is never the only signal
/// (colorblind + grayscale-screen-in-sunlight safe), per UI_SPEC.md.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.text,
    required this.tone,
    this.icon,
  });

  final String text;
  final StatusTone tone;

  /// Overrides the tone's default icon where the chip means something more
  /// specific than its tone (a day chip is not an information notice).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors(tone);
    final resolvedIcon =
        icon ??
        switch (tone) {
          StatusTone.success => Icons.check_circle,
          StatusTone.danger => Icons.error,
          _ => Icons.info,
        };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(resolvedIcon, size: 16, color: colors.content),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: AppTypography.labelMedium.copyWith(
                  color: colors.content,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
