import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';
import 'mock_jawwal_pay_service.dart';
import 'payment_otp_screen.dart';
import '../../core/widgets/labeled_field.dart';

/// Screen where user reviews and confirms their registered Jawwal Pay number
/// before the simulated OTP is generated.
class PaymentNumberScreen extends StatefulWidget {
  const PaymentNumberScreen({
    super.key,
    required this.initialNumber,
    this.service,
  });

  final String initialNumber;
  final MockJawwalPayService? service;

  @override
  State<PaymentNumberScreen> createState() => _PaymentNumberScreenState();
}

class _PaymentNumberScreenState extends State<PaymentNumberScreen> {
  late final TextEditingController _phoneController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.initialNumber);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _proceed() async {
    final number = _phoneController.text.trim();
    if (number.isEmpty) {
      setState(() => _error = Strings.registerError);
      return;
    }

    setState(() => _error = null);
    final service = widget.service ?? MockJawwalPayService();
    final success = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentOtpScreen(service: service, phoneNumber: number),
      ),
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
        title: const Text(Strings.paymentTitle),
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
                  Center(
                    child: SvgPicture.asset(
                      'assets/images/stitch_loaf.svg',
                      width: 72,
                      height: 56,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ExcludeSemantics(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.accentContainer,
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.account_balance_wallet_outlined,
                                  color: AppColors.accent, size: 28),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          Strings.confirmJawwalPayNumber,
                          style: AppTypography.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          Strings.jawwalPayPrompt,
                          style: AppTypography.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        LabeledField(
                          label: Strings.jawwalPayNumberLabel,
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            style: AppTypography.bodyLarge,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _proceed(),
                            decoration: const InputDecoration(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    StatusChip(text: _error!, tone: StatusTone.danger),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    text: Strings.proceedToOtp,
                    onPressed: _proceed,
                  ),
                  const SizedBox(height: AppSpacing.sm),
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
