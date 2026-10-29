import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../auth/bloc/auth_bloc.dart';

/// Mock verification: auto-approves after a short delay (VerificationApprovedEvent).
/// Real ID/face-match, and a rejection path, are out of scope for this
/// prototype — see spec.md.
class WaitingForVerificationScreen extends StatefulWidget {
  const WaitingForVerificationScreen({super.key});

  @override
  State<WaitingForVerificationScreen> createState() =>
      _WaitingForVerificationScreenState();
}

class _WaitingForVerificationScreenState
    extends State<WaitingForVerificationScreen> {
  bool _approved = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _approved = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      height: 80,
                      width: 80,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accentContainer,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: SvgPicture.asset(
                        'assets/images/stitch_loaf.svg',
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'رغيف',
                    textAlign: TextAlign.center,
                    style: textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'الخطوة ٣ من ٣ · إكمال الإعداد',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          height: 88,
                          width: 88,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _approved
                                ? AppColors.successContainer
                                : AppColors.accentContainer,
                            shape: BoxShape.circle,
                          ),
                          child: _approved
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 40,
                                  color: AppColors.success,
                                )
                              : const CircularProgressIndicator(
                                  strokeWidth: 3,
                                  semanticsLabel: 'جارٍ إكمال الخطوة التجريبية',
                                ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _approved
                                ? 'حسابك جاهز للتجربة'
                                : 'لحظات ويكتمل الإعداد',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _approved
                              ? Strings.verifiedBody
                              : 'يرجى الانتظار قليلاً لإكمال خطوة التحقق التجريبية.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'هذه تجربة للواجهة. لم تُجرَ مراجعة للصور أو مطابقة فعلية للهوية.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_approved) ...[
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      text: Strings.continueToApp,
                      onPressed: () {
                        context.read<AuthBloc>().add(
                          const VerificationApprovedEvent(),
                        );
                        // The ID/selfie/waiting steps are all pushed routes;
                        // pop back to the state-driven root so it can swap
                        // to StoreListScreen now that isVerified is true.
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
