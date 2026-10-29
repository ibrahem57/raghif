import 'package:flutter/material.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';
import 'mock_jawwal_pay_service.dart';
import 'payment_success_screen.dart';
import '../../core/widgets/labeled_field.dart';

/// Screen where user verifies the 4-digit mock OTP code for Jawwal Pay payment.
class PaymentOtpScreen extends StatefulWidget {
  const PaymentOtpScreen({
    super.key,
    required this.service,
    required this.phoneNumber,
  });

  final MockJawwalPayService service;
  final String phoneNumber;

  @override
  State<PaymentOtpScreen> createState() => _PaymentOtpScreenState();
}

class _PaymentOtpScreenState extends State<PaymentOtpScreen> {
  final _codeController = TextEditingController();
  late String _currentCode;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Mock payment, no SMS: the code is shown on this screen, not pushed.
    _currentCode = widget.service.generateCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _resend() {
    setState(() {
      _currentCode = widget.service.resendCode();
      _error = null;
    });
  }

  void _confirm() async {
    final entered = _codeController.text.trim();
    if (!widget.service.verifyCode(entered)) {
      setState(() => _error = Strings.wrongOtpError);
      return;
    }

    setState(() => _error = null);
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PaymentSuccessScreen()),
    );

    if (success == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(Strings.paymentOtpTitle),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: AppTypography.titleMedium,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Icon(Icons.password_rounded,
                              color: AppColors.accent, size: 32),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    Strings.paymentOtpInstructions,
                    style: AppTypography.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${Strings.phoneLabel}: \u2066${widget.phoneNumber}\u2069',
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ExcludeSemantics(
                          child: Icon(Icons.info_outline, color: AppColors.accent),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            Strings.demoOtpNotification(_currentCode),
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LabeledField(
                    label: Strings.paymentOtpLabel,
                    child: TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: AppTypography.displayMedium,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _confirm(),
                      maxLength: 4,
                      decoration: const InputDecoration(counterText: ''),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    StatusChip(text: _error!, tone: StatusTone.danger),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    text: Strings.confirmPaymentButton,
                    onPressed: _confirm,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Center(
                    child: TextButton(
                      onPressed: _resend,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: AppColors.accent,
                        textStyle: AppTypography.labelMedium,
                      ),
                      child: const Text(Strings.resendCodeButton),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SecondaryButton(
                    text: Strings.back,
                    onPressed: () => Navigator.of(context).pop(false),
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
