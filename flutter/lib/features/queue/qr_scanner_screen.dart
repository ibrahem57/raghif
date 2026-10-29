import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../domain/models/purchase_model.dart';
import 'qr_payload.dart';
import 'qr_redemption.dart';
import 'queue_controller.dart';
import 'scan_feedback.dart';
import 'write_guard.dart';

/// Issue #28: in-app QR redemption scanner for [OwnerQueueScreen].
///
/// Camera-only surface — all decode/match decisions live in
/// [evaluateQrRedemption] so they are testable without a camera. Once a code
/// is read, the camera stops and the result state takes over; "مسح رمز آخر"
/// restarts it.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({
    super.key,
    required this.controller,
    required this.storeId,
  });

  final QueueController controller;
  final String storeId;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scanner = MobileScannerController();
  final ScanFeedbackPlayer _feedback = ScanFeedbackPlayer();

  String? _ownerStoreId;
  bool _scanning = true;
  bool _processing = false;
  bool _cameraError = false;
  bool _invalidCode = false;
  QrRedemptionResult? _result;

  @override
  void initState() {
    super.initState();
    _ownerStoreId = widget.controller.storeById(widget.storeId)?.id;
  }

  @override
  void dispose() {
    _scanner.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_scanning || _processing) return;
    final raw = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _processing = true;
    await _scanner.stop();

    final payload = QrPayload.tryDecode(raw);
    if (payload == null) {
      // Not a receipt payload at all — still an audit-worthy attempt.
      await _feedback.play(ScanFeedback.failure);
      if (!mounted) return;
      final logged = await guardWrite(
        context,
        () => widget.controller.recordScan(
          storeId: widget.storeId,
          outcome: 'invalidCode',
        ),
      );
      if (!mounted) return;
      if (!logged) return _abortScan();
      setState(() {
        _processing = false;
        _invalidCode = true;
        _result = null;
      });
      return;
    }

    if (!mounted) return;
    PurchaseModel? purchase;
    final looked = await guardWrite(context, () async {
      purchase = await widget.controller.purchaseById(payload.purchaseId);
    });
    if (!mounted) return;
    if (!looked) return _abortScan();
    final result = evaluateQrRedemption(
      payload: payload,
      purchase: purchase,
      ownerStoreId: _ownerStoreId ?? '',
    );
    if (result.outcome == QrRedemptionOutcome.checkedIn &&
        result.purchase != null) {
      final collected = await guardWrite(
        context,
        () => widget.controller.collectPurchase(result.purchase!.id),
      );
      if (!mounted) return;
      // Not collected on the server means no bag is handed over: say so and
      // let the owner scan again instead of showing a success screen.
      if (!collected) return _abortScan();
    }
    await _feedback.play(scanFeedbackFor(result.outcome));
    if (!mounted) return;
    final logged = await guardWrite(
      context,
      () => widget.controller.recordScan(
        storeId: widget.storeId,
        outcome: result.outcome.name,
        purchaseId: result.purchase?.id,
        scannedName: payload.userName,
        scannedNationalId: payload.nationalId,
      ),
    );
    if (!mounted) return;
    if (!logged) return _abortScan();
    setState(() {
      _processing = false;
      _result = result;
      _invalidCode = false;
    });
  }

  /// A write failed (the snackbar already said so): resume scanning rather
  /// than leaving the camera stopped and the screen stuck on "processing".
  Future<void> _abortScan() async {
    _processing = false;
    await _scanner.start();
  }

  Future<void> _rescan() async {
    setState(() {
      _result = null;
      _invalidCode = false;
      _cameraError = false;
    });
    await _scanner.start();
    setState(() => _scanning = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(Strings.scanQrTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _result != null
                ? _ResultView(
                    result: _result!,
                    onRescan: _rescan,
                    onDone: () => Navigator.of(context).pop(),
                  )
                : _invalidCode
                ? _MessageView(
                    icon: Icons.error_outline,
                    title: Strings.scanInvalidCode,
                    onPrimary: _rescan,
                    primaryLabel: Strings.scanAgain,
                    onSecondary: () => Navigator.of(context).pop(),
                  )
                : _cameraError
                ? _MessageView(
                    icon: Icons.no_photography_outlined,
                    title: Strings.scanCameraError,
                    onPrimary: _rescan,
                    primaryLabel: Strings.scanAgain,
                    onSecondary: () => Navigator.of(context).pop(),
                  )
                : _cameraView(),
          ),
        ),
      ),
    );
  }

  Widget _cameraView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.scanQrTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      Strings.scanCameraHint,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: (constraints.maxHeight * .62).clamp(280.0, 440.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _scanner,
                        onDetect: _onDetect,
                        errorBuilder: (context, error) {
                          // Permission denied / camera unavailable — surface once.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted && !_cameraError) {
                              setState(() => _cameraError = true);
                            }
                          });
                          return const SizedBox.shrink();
                        },
                      ),
                      const IgnorePointer(
                        child: Center(
                          child: FractionallySizedBox(
                            widthFactor: .72,
                            heightFactor: .66,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.fromBorderSide(
                                  BorderSide(color: Colors.white, width: 3),
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(24),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (!_cameraError) _TorchButton(scanner: _scanner),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                text: Strings.back,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Low-light aid: a torch (flashlight) toggle floating over the camera
/// preview. Hidden on devices without a torch (state stays `unavailable`).
/// The controller notifies through its [MobileScannerState.torchState] — the
/// platform turns the torch off again as soon as the camera stops.
class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.scanner});

  final MobileScannerController scanner;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MobileScannerState>(
      valueListenable: scanner,
      builder: (context, state, _) {
        final torch = state.torchState;
        final hasTorch = state.isRunning && torch != TorchState.unavailable;
        if (!hasTorch) return const SizedBox.shrink();
        final isOn = torch == TorchState.on;
        return Align(
          alignment: AlignmentDirectional.bottomEnd,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: isOn ? Strings.scanTorchOff : Strings.scanTorchOn,
                icon: Icon(
                  isOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                ),
                onPressed: () => scanner.toggleTorch(),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Full decoded details are always shown (issue #28: never a silent failure) —
/// the header/icon communicates what happened, the card shows what was encoded.
class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.result,
    required this.onRescan,
    required this.onDone,
  });

  final QrRedemptionResult result;
  final VoidCallback onRescan;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body, tone) = switch (result.outcome) {
      QrRedemptionOutcome.staleReceipt => (
        Icons.event_busy_outlined,
        'رمز الحجز قديم',
        'تم تغيير موعد الحجز. افتح الإيصال المحدّث من حساب المشتري.',
        AppColors.warning,
      ),
      QrRedemptionOutcome.checkedIn => (
        Icons.check_circle_outline,
        Strings.scanCheckedInTitle,
        Strings.scanCheckedInBody,
        AppColors.success,
      ),
      QrRedemptionOutcome.alreadyCollected => (
        Icons.verified_outlined,
        Strings.scanAlreadyCollected,
        null,
        AppColors.success,
      ),
      QrRedemptionOutcome.batchNotCalledYet => (
        Icons.schedule_outlined,
        Strings.scanBatchNotCalledYet(result.batchNumber ?? 0),
        null,
        AppColors.warning,
      ),
      QrRedemptionOutcome.notFoundHere => (
        Icons.search_off_outlined,
        Strings.scanNotFoundTitle,
        Strings.scanNotFoundBody,
        AppColors.textSecondary,
      ),
      QrRedemptionOutcome.wrongStore => (
        Icons.store_outlined,
        Strings.scanWrongStoreTitle,
        Strings.scanWrongStoreBody(result.actualStoreName ?? '—'),
        AppColors.danger,
      ),
    };

    final payload = result.payload;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: .1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: tone),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payload.userName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${payload.storeName} · ${payload.purchaseDate}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (payload.nationalId != null &&
                    payload.nationalId!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${Strings.idShortLabel}: ${payload.nationalId}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  payload.purchaseId,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(text: Strings.scanAgain, onPressed: onRescan),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(text: Strings.back, onPressed: onDone),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.onPrimary,
    required this.primaryLabel,
    required this.onSecondary,
  });

  final IconData icon;
  final String title;
  final VoidCallback onPrimary;
  final String primaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.dangerContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: AppColors.danger),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(text: primaryLabel, onPressed: onPrimary),
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(text: Strings.back, onPressed: onSecondary),
        ],
      ),
    );
  }
}
