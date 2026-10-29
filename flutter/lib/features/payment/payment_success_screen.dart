import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';

/// Screen displayed after the mock Jawwal Pay OTP is verified successfully.
/// Tapping the action button completes the payment flow and triggers the
/// reservation creation.
class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(Strings.paymentSuccessTitle),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTypography.titleMedium,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: SvgPicture.asset(
                        'assets/images/stitch_loaf.svg',
                        width: 96,
                        height: 72,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const ExcludeSemantics(
                    child: Icon(Icons.check_circle_outline,
                        color: AppColors.success, size: 40),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    Strings.paymentSuccessTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.displayMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Text(
                      Strings.paymentSuccessMessage,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyLarge,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    text: Strings.completeReservationButton,
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
