import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/status_chip.dart';
import 'bloc/auth_bloc.dart';
import '../../core/widgets/labeled_field.dart';

/// Dedicated registration form — name, phone, national ID, PIN, and the
/// Jawwal Pay number (saved once here, reused at purchase time). Reached
/// from onboarding's "إنشاء حساب" or an unrecognized National ID at login.
///
/// Grouped into what the account *is* and what it's used *for*, with one
/// message per field: a blank form used to answer "يرجى تعبئة جميع الحقول",
/// which tells the user nothing about which of five fields is missing. The PIN
/// is asked for twice because it is the login credential and this pilot has no
/// reset flow — mistyping it once would lock the account out for good.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, this.initialPhone});

  final String? initialPhone;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _phoneController = TextEditingController(
    text: widget.initialPhone,
  );
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _nameController = TextEditingController();
  final _personalIdController = TextEditingController();
  final _jawwalPayController = TextEditingController();

  /// Set once the user types their own wallet number, so the phone-number
  /// mirroring below stops overwriting their edit.
  bool _jawwalEditedManually = false;

  bool _showPin = false;
  String? _formError;

  static final _palestinianMobile = RegExp(r'^05\d{8}$');

  @override
  void initState() {
    super.initState();
    // Jawwal Pay is SIM-tied — default it to the phone number being
    // registered, editable if the user's wallet number actually differs.
    _jawwalPayController.text = _phoneController.text;
    _phoneController.addListener(_mirrorPhoneIntoJawwal);
  }

  /// Copies the phone number into the wallet field until the user edits the
  /// wallet field directly (then their value wins).
  void _mirrorPhoneIntoJawwal() {
    if (_jawwalEditedManually) return;
    if (_jawwalPayController.text != _phoneController.text) {
      _jawwalPayController.text = _phoneController.text;
    }
  }

  /// Clearing the wallet field hands control back to the phone default;
  /// typing anything else marks it as the user's own number.
  void _onJawwalChanged(String value) {
    if (value.trim().isEmpty) {
      _jawwalEditedManually = false;
      _mirrorPhoneIntoJawwal();
    } else {
      _jawwalEditedManually = true;
    }
  }

  @override
  void dispose() {
    _phoneController.removeListener(_mirrorPhoneIntoJawwal);
    _phoneController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _nameController.dispose();
    _personalIdController.dispose();
    _jawwalPayController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) =>
      (value ?? '').trim().isEmpty ? Strings.nameRequired : null;

  String? _validatePhone(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return Strings.phoneRequired;
    return _palestinianMobile.hasMatch(text) ? null : Strings.phoneInvalid;
  }

  String? _validateNationalId(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return Strings.nationalIdRequired;
    return text.length == 9 ? null : Strings.nationalIdLengthError;
  }

  String? _validatePin(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return Strings.pinRequired;
    return text.length == 4 ? null : Strings.pinLengthError;
  }

  String? _validateConfirmPin(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return Strings.pinRequired;
    return text == _pinController.text.trim() ? null : Strings.pinMismatch;
  }

  String? _validateJawwalPay(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return Strings.jawwalPayRequired;
    return _palestinianMobile.hasMatch(text) ? null : Strings.jawwalPayInvalid;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      setState(() => _formError = null);
      return;
    }
    setState(() => _formError = null);
    context.read<AuthBloc>().add(
      RegisterRequestedEvent(
        phone: _phoneController.text.trim(),
        pin: _pinController.text.trim(),
        nationalId: _personalIdController.text.trim(),
        name: _nameController.text.trim(),
        jawwalPayNumber: _jawwalPayController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          setState(() => _formError = state.errorMessage);
        } else if (state is Authenticated) {
          // This screen is a pushed route; the base route already swapped
          // to the post-registration flow underneath, so pop back to it
          // rather than leaving the form stuck on top.
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              scrolledUnderElevation: 0,
              title: const Text(Strings.registrationTitle),
            ),
            body: SafeArea(
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Container(
                                width: 76,
                                height: 76,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.accentContainer,
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: SvgPicture.asset(
                                  'assets/images/stitch_loaf.svg',
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'رغيف',
                              textAlign: TextAlign.center,
                              style: textTheme.displayMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              Strings.registrationSubtitle,
                              textAlign: TextAlign.center,
                              style: textTheme.bodyLarge?.copyWith(
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _sectionLabel(
                              Strings.registrationAccountSection,
                              textTheme,
                              muted,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LabeledField(
                                    label: Strings.nameLabel,
                                    child: TextFormField(
                                      controller: _nameController,
                                      enabled: !isLoading,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [AutofillHints.name],
                                      validator: _validateName,
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(
                                          Icons.person_outline_rounded,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  LabeledField(
                                    label: Strings.phoneLabel,
                                    child: TextFormField(
                                      controller: _phoneController,
                                      enabled: !isLoading,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.next,
                                      autofillHints: const [
                                        AutofillHints.telephoneNumber,
                                      ],
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      validator: _validatePhone,
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(
                                          Icons.phone_android_rounded,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  LabeledField(
                                    label: Strings.personalIdLabel,
                                    child: TextFormField(
                                      controller: _personalIdController,
                                      enabled: !isLoading,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(9),
                                      ],
                                      validator: _validateNationalId,
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(Icons.badge_outlined),
                                        helperText: Strings.nationalIdHelper,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _sectionLabel(
                              Strings.registrationPaymentSection,
                              textTheme,
                              muted,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  LabeledField(
                                    label: Strings.pinLabel,
                                    child: TextFormField(
                                      controller: _pinController,
                                      enabled: !isLoading,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      obscureText: !_showPin,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                      ],
                                      validator: _validatePin,
                                      decoration: InputDecoration(
                                        prefixIcon: const Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                        helperText: Strings.pinHelper,
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _showPin = !_showPin,
                                          ),
                                          tooltip: _showPin
                                              ? Strings.hidePin
                                              : Strings.showPin,
                                          icon: Icon(
                                            _showPin
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: muted,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  LabeledField(
                                    label: Strings.confirmPinLabel,
                                    child: TextFormField(
                                      controller: _confirmPinController,
                                      enabled: !isLoading,
                                      keyboardType: TextInputType.number,
                                      textInputAction: TextInputAction.next,
                                      obscureText: !_showPin,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(4),
                                      ],
                                      validator: _validateConfirmPin,
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  LabeledField(
                                    label: Strings.jawwalPayNumberLabel,
                                    child: TextFormField(
                                      controller: _jawwalPayController,
                                      enabled: !isLoading,
                                      onChanged: _onJawwalChanged,
                                      keyboardType: TextInputType.phone,
                                      textInputAction: TextInputAction.done,
                                      onFieldSubmitted: (_) => _submit(),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      validator: _validateJawwalPay,
                                      decoration: const InputDecoration(
                                        prefixIcon: Icon(
                                          Icons.account_balance_wallet_outlined,
                                        ),
                                        helperText: Strings.jawwalPayNumberHint,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_formError != null) ...[
                              const SizedBox(height: AppSpacing.md),
                              Semantics(
                                liveRegion: true,
                                child: StatusChip(
                                  text: _formError!,
                                  tone: StatusTone.danger,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.lg),
                            PrimaryButton(
                              text: Strings.registerButton,
                              loading: isLoading,
                              onPressed: _submit,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text, TextTheme textTheme, Color muted) {
    return Text(text, style: textTheme.labelMedium?.copyWith(color: muted));
  }
}
