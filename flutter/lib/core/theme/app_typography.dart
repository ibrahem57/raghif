import 'package:flutter/material.dart';
import 'app_colors.dart';

const _fontFamily = 'IBMPlexSansArabic';

/// Sizes per UI_SPEC.md token table — legible in sunlight, for a queue app
/// used standing up. Body text is 16sp or more (constitution V); nothing in
/// the app goes below 15sp. No style sets `letterSpacing`: Flutter turns off
/// ligatures when it is non-zero, and Arabic depends on them to join.
class AppTypography {
  AppTypography._();

  static const displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 28,
    height: 42 / 28,
    color: AppColors.textPrimary,
  );
  static const displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 36 / 24,
    color: AppColors.textPrimary,
  );
  static const titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 33 / 22,
    color: AppColors.textPrimary,
  );
  static const titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 27 / 18,
    color: AppColors.textPrimary,
  );
  static const bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 17,
    height: 26 / 17,
    color: AppColors.textPrimary,
  );
  static const bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 24 / 16,
    color: AppColors.textSecondary,
  );
  static const labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 24 / 16,
    color: AppColors.onAccent,
  );
  static const labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 24 / 16,
  );

  /// Secondary/caption role, held at the same 16sp as [bodyMedium]
  /// instead of Material's 12sp default. Helper text, field errors and inline
  /// captions are the only small print the app has, and they get read outdoors
  /// by someone who left their glasses at home.
  ///
  /// Leaving these two undefined did not mean "no caption text": it meant every
  /// helper, error and counter line silently rendered at Roboto 12sp from the
  /// Material defaults, outside the design system — which is also why they came
  /// out as tofu boxes in the goldens, since only NotoSansArabic is loaded
  /// there.
  static const bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 24 / 16,
    color: AppColors.textSecondary,
  );
  static const labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 24 / 16,
    color: AppColors.textSecondary,
  );
}
