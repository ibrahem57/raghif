import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/labeled_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/status_chip.dart';
import 'bloc/auth_bloc.dart';
import 'demo_accounts.dart';
import 'registration_screen.dart';

enum _Step { id, pin, otp }

/// One question per screen: who are you (national ID), then your PIN. The
/// code by "SMS" is the way back in when the PIN is forgotten, not a second
/// front door — a returning user should meet two fields in total, never a
/// choice between login methods.
///
/// Errors sit on the field they belong to, with the recovery next to them.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _resendCooldownSeconds = 30;

  final _idController = TextEditingController();
  final _pinController = TextEditingController();
  final _otpController = TextEditingController();

  _Step _step = _Step.id;
  bool _showPin = false;
  String? _demoOtpCode;

  String? _idError;
  String? _pinError;
  String? _otpError;
  String? _formError;

  /// The server said this ID has no account: offer registration right where
  /// the message appears instead of making the user hunt for it.
  bool _notRegistered = false;

  int _resendIn = 0;
  Timer? _cooldown;

  @override
  void dispose() {
    _cooldown?.cancel();
    _idController.dispose();
    _pinController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // --- validation ---------------------------------------------------------

  String? _validateId() {
    final value = _idController.text.trim();
    if (value.isEmpty) return Strings.nationalIdRequired;
    if (value.length != 9) return Strings.nationalIdLengthError;
    return null;
  }

  String? _validatePin() {
    final value = _pinController.text.trim();
    if (value.isEmpty) return Strings.pinRequired;
    if (value.length != 4) return Strings.pinLengthError;
    return null;
  }

  String? _validateOtp() {
    final value = _otpController.text.trim();
    if (value.isEmpty) return Strings.otpRequired;
    if (value.length != 4) return Strings.otpLengthError;
    return null;
  }

  void _clearErrors() {
    if (_idError == null &&
        _pinError == null &&
        _otpError == null &&
        _formError == null) {
      return;
    }
    setState(() {
      _notRegistered = false;
      _idError = null;
      _pinError = null;
      _otpError = null;
      _formError = null;
    });
  }

  // --- actions ------------------------------------------------------------

  void _continue() {
    final error = _validateId();
    setState(() {
      _idError = error;
      _formError = null;
      if (error == null) _step = _Step.pin;
    });
  }

  void _submitPin() {
    final error = _validatePin();
    setState(() {
      _pinError = error;
      _formError = null;
    });
    if (error != null) return;
    context.read<AuthBloc>().add(
      PinLoginRequestedEvent(
        nationalId: _idController.text.trim(),
        pin: _pinController.text.trim(),
      ),
    );
  }

  void _requestOtp() {
    setState(() => _formError = null);
    context.read<AuthBloc>().add(
      RequestOtpEvent(nationalId: _idController.text.trim()),
    );
  }

  void _resendOtp() {
    if (_resendIn > 0) return;
    _requestOtp();
  }

  void _verifyOtp() {
    final error = _validateOtp();
    setState(() {
      _otpError = error;
      _formError = null;
    });
    if (error != null) return;
    context.read<AuthBloc>().add(
      VerifyOtpEvent(
        nationalId: _idController.text.trim(),
        otp: _otpController.text.trim(),
      ),
    );
  }

  /// The pilot has no SMS, so the code is on screen anyway — retyping four
  /// digits adds nothing but typos.
  void _fillDemoOtp() {
    final code = _demoOtpCode;
    if (code == null) return;
    _otpController.text = code;
    _verifyOtp();
  }

  void _back() {
    _cooldown?.cancel();
    setState(() {
      _formError = null;
      _idError = null;
      _pinError = null;
      _otpError = null;
      _resendIn = 0;
      if (_step == _Step.otp) {
        _otpController.clear();
        _step = _Step.pin;
      } else {
        _pinController.clear();
        _step = _Step.id;
      }
    });
  }

  void _startResendCooldown() {
    _cooldown?.cancel();
    _resendIn = _resendCooldownSeconds;
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn = _resendIn - 1);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  void _goToRegistration() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const RegistrationScreen()));
  }

  /// Pilot credentials for testing. One tap signs in — the alternative is
  /// copying nine digits off a sheet by hand on the phone under test.
  Future<void> _showDemoAccounts() async {
    final picked = await showModalBottomSheet<({String id, String pin})>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                Strings.demoAccountsTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _demoRow(
                sheetContext,
                Strings.demoBuyerLabel,
                demoBuyerNationalId,
                demoBuyerPin,
              ),
              const SizedBox(height: AppSpacing.sm),
              _demoRow(
                sheetContext,
                demoBuyer2Name,
                demoBuyer2NationalId,
                demoBuyer2Pin,
              ),
              const SizedBox(height: AppSpacing.sm),
              _demoRow(
                sheetContext,
                Strings.demoOwnerLabel,
                demoOwnerNationalId,
                demoOwnerPin,
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _idController.text = picked.id;
      _pinController.text = picked.pin;
      _step = _Step.pin;
      _idError = _pinError = _formError = null;
    });
    _submitPin();
  }

  Widget _demoRow(BuildContext sheet, String label, String id, String pin) {
    return Semantics(
      button: true,
      label: Strings.fillDemoAccount(label),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        onTap: () => Navigator.of(sheet).pop((id: id, pin: pin)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '$label — $id / $pin',
              style: Theme.of(sheet).textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }

  // --- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          setState(() => _formError = state.errorMessage);
        } else if (state is AuthSwitchToRegister) {
          setState(() {
            _formError = Strings.nationalIdNotFound;
            _notRegistered = true;
          });
        } else if (state is AuthOtpSent) {
          setState(() {
            _step = _Step.otp;
            _demoOtpCode = state.otpCode;
            _formError = null;
            _otpError = null;
            _otpController.clear();
          });
          _startResendCooldown();
        } else if (state is Authenticated) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return PopScope(
            canPop: _step == _Step.id,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _back();
            },
            child: Scaffold(
              appBar: AppBar(
                toolbarHeight: _step == _Step.id ? 16 : kToolbarHeight,
                backgroundColor: Colors.transparent,
                scrolledUnderElevation: 0,
                automaticallyImplyLeading: false,
                leading: _step == _Step.id
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.arrow_back),
                        tooltip: Strings.back,
                        onPressed: isLoading ? null : _back,
                      ),
              ),
              body: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: _content(isLoading),
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

  Widget _content(bool isLoading) {
    final textTheme = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).height < 720;
    final title = switch (_step) {
      _Step.id => Strings.loginIdTitle,
      _Step.pin => Strings.loginPinTitle,
      _Step.otp => Strings.loginOtpTitle,
    };
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compact)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/images/stitch_loaf.svg',
                  width: 48,
                  height: 48,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'رغيف',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppColors.accentContainer,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(
                  'assets/images/stitch_loaf.svg',
                  width: 52,
                  height: 52,
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
          ],
          SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
          Container(
            padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_step != _Step.id) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    Strings.loginForId(_idController.text.trim()),
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                switch (_step) {
                  _Step.id => _idStep(isLoading),
                  _Step.pin => _pinStep(isLoading),
                  _Step.otp => _otpStep(isLoading),
                },
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _error() {
    final error = _formError;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: StatusChip(text: error, tone: StatusTone.danger),
      ),
    );
  }

  Widget _registerOffer() {
    if (!_notRegistered) return const SizedBox.shrink();
    return Center(
      child: TextButton(
        onPressed: _goToRegistration,
        child: const Text(Strings.createAccountLink),
      ),
    );
  }

  Widget _idStep(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: Strings.personalIdLabel,
          child: TextField(
            controller: _idController,
            enabled: !isLoading,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.username],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            onChanged: (_) => _clearErrors(),
            onSubmitted: (_) => _continue(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.badge_outlined),
              helperText: Strings.nationalIdHelper,
              errorText: _idError,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(text: Strings.continueButton, onPressed: _continue),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            onPressed: _goToRegistration,
            child: const Text(Strings.createAccountLink),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _showDemoAccounts,
            child: Text(
              Strings.demoAccountsTitle,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _pinStep(bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledField(
          label: Strings.pinLabel,
          child: TextField(
            controller: _pinController,
            enabled: !isLoading,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            obscureText: !_showPin,
            autofillHints: const [AutofillHints.password],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            // A complete PIN is a submitted PIN: nobody hunts for the button
            // with a full field.
            onChanged: (value) {
              _clearErrors();
              if (value.trim().length == 4) _submitPin();
            },
            onSubmitted: (_) => _submitPin(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              errorText: _pinError,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _showPin = !_showPin),
                tooltip: _showPin ? Strings.hidePin : Strings.showPin,
                icon: Icon(
                  _showPin ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        _error(),
        _registerOffer(),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          text: Strings.loginButton,
          loading: isLoading,
          onPressed: _submitPin,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            onPressed: isLoading ? null : _requestOtp,
            child: const Text(Strings.forgotPin),
          ),
        ),
      ],
    );
  }

  Widget _otpStep(bool isLoading) {
    final textTheme = Theme.of(context).textTheme;
    final code = _demoOtpCode;
    final waiting = _resendIn > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (code != null) ...[
          // Visibly simulated (constitution VI): no SMS is sent, the code is
          // here, and tapping it fills the field.
          Semantics(
            button: true,
            label: Strings.demoOtpTapToFill,
            child: InkWell(
              onTap: isLoading ? null : _fillDemoOtp,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.accentContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.demoOtpBanner(code),
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(Strings.demoOtpTapToFill, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        LabeledField(
          label: Strings.otpLabel,
          child: TextField(
            controller: _otpController,
            enabled: !isLoading,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(letterSpacing: 8),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            // A complete code is a submitted code.
            onChanged: (value) {
              _clearErrors();
              if (value.trim().length == 4) _verifyOtp();
            },
            onSubmitted: (_) => _verifyOtp(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.sms_outlined),
              errorText: _otpError,
            ),
          ),
        ),
        _error(),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          text: Strings.verifyOtpButton,
          loading: isLoading,
          onPressed: _verifyOtp,
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: TextButton(
            onPressed: (isLoading || waiting) ? null : _resendOtp,
            child: Text(
              waiting ? Strings.resendOtpIn(_resendIn) : Strings.resendOtp,
            ),
          ),
        ),
      ],
    );
  }
}
