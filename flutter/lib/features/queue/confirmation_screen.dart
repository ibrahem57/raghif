import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';
import '../auth/demo_accounts.dart';
import '../../domain/models/purchase_model.dart';
import 'qr_payload.dart';
import 'queue_controller.dart';
import 'receipt_card.dart';

/// UI_SPEC.md ConfirmationScreen: big status statement, batch/store at
/// titleMedium, plain-language status while waiting rather than a raw
/// countdown digit grid.
class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({
    super.key,
    required this.controller,
    required this.purchaseId,
    required this.currentUser,
  });

  final QueueController controller;
  final String purchaseId;
  final DemoUser currentUser;

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  final GlobalKey _receiptKey = GlobalKey();

  late final Stream<PurchaseModel?> _purchaseStream = widget.controller
      .watchPurchase(widget.purchaseId);

  String? _queueStreamStoreId;
  String? _queueStreamDate;
  Stream<List<PurchaseModel>>? _queueStream;

  // The inner StreamBuilder's `stream` must stay the same instance across
  // rebuilds of the outer one, or it resubscribes (and Drift's watch()
  // re-runs its initial query) every time the purchase stream re-emits —
  // even when the store/date it targets hasn't actually changed. Cache it,
  // only rebuilding when storeId/date genuinely change.
  Stream<List<PurchaseModel>> _queueStreamFor(String storeId, String date) {
    if (_queueStreamStoreId != storeId || _queueStreamDate != date) {
      _queueStreamStoreId = storeId;
      _queueStreamDate = date;
      _queueStream = widget.controller.watchQueueForStore(storeId, date);
    }
    return _queueStream!;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final currentUser = widget.currentUser;
    return Scaffold(
      appBar: AppBar(title: Text(Strings.confirmationTitle)),
      body: StreamBuilder<PurchaseModel?>(
        stream: _purchaseStream,
        initialData: controller.cachedPurchase(widget.purchaseId),
        builder: (context, purchaseSnapshot) {
          final purchase = purchaseSnapshot.data;
          if (purchase == null) return const SizedBox.shrink();

          return StreamBuilder<List<PurchaseModel>>(
            stream: _queueStreamFor(purchase.storeId, purchase.purchaseDate),
            builder: (context, queueSnapshot) {
              final queue = queueSnapshot.data ?? [];
              final position = queue.indexWhere((p) => p.id == purchase.id) + 1;
              final store = controller.storeById(purchase.storeId);
              // Farid's comment — PRODUCTION: this is where the receipt QR is
              // minted CLIENT-side today (prototype). In production the code
              // must come from the backend as an opaque signed token — see
              // the full production roadmap in qr_payload.dart. When that
              // lands, delete encode()/QrImageView usage here.
              final qrPayload = QrPayload(
                purchaseId: purchase.id,
                userName: purchase.userName ?? currentUser.name,
                storeName: purchase.storeName ?? store?.name ?? '',
                purchaseDate: purchase.purchaseDate,
                nationalId: purchase.userNationalId,
                storeId: purchase.storeId,
              );

              final (statusLabel, tone) = switch (purchase.status) {
                PurchaseStatus.waiting => (
                  Strings.statusWaiting,
                  StatusTone.warning,
                ),
                PurchaseStatus.notified => (
                  Strings.statusNotified,
                  StatusTone.success,
                ),
                PurchaseStatus.collected => (
                  Strings.statusCollectedShort,
                  StatusTone.neutral,
                ),
              };
              final headline = switch (purchase.status) {
                PurchaseStatus.waiting => 'تم حجز ربطتك',
                PurchaseStatus.notified => Strings.statusNotified,
                PurchaseStatus.collected => Strings.statusCollectedShort,
              };
              return SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 80,
                              height: 80,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.successContainer,
                              ),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.success,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            headline,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (purchase.status != PurchaseStatus.collected) ...[
                            const SizedBox(height: 8),
                            Text(
                              purchase.status == PurchaseStatus.waiting
                                  ? Strings.waitingReassurance
                                  : Strings.batchReadyNotificationBody,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Center(
                            child: StatusChip(
                              text: purchase.status == PurchaseStatus.waiting
                                  ? statusLabel
                                  : purchase.status == PurchaseStatus.notified
                                  ? Strings.statusNotifiedShort
                                  : 'اكتمل طلبك',
                              tone: tone,
                            ),
                          ),
                          const SizedBox(height: 24),
                          RepaintBoundary(
                            key: _receiptKey,
                            child: ReceiptCard(
                              storeName: qrPayload.storeName,
                              purchaseId: qrPayload.purchaseId,
                              purchaseDate: qrPayload.purchaseDate,
                              batchNumber: purchase.batchNumber,
                              userName: qrPayload.userName,
                              status: purchase.status,
                              qrData: qrPayload.encode(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: [
                              if (position > 0)
                                StatusChip(
                                  text: '${Strings.queuePosition} $position',
                                  tone: StatusTone.neutral,
                                ),
                              StatusChip(
                                text: Strings.batchLabel(purchase.batchNumber),
                                tone: StatusTone.neutral,
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SecondaryButton(
                            text: Strings.saveQrButton,
                            onPressed: () =>
                                _saveQrToGallery(context, qrPayload),
                          ),
                          const SizedBox(height: 12),
                          SecondaryButton(
                            text: Strings.shareQrButton,
                            onPressed: () => _shareQr(context, qrPayload),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            text: Strings.returnToStores,
                            onPressed: () => Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<Uint8List?> _captureReceiptBytes() async {
    try {
      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      final image = await boundary?.toImage(pixelRatio: 3.0);
      final byteData = await image?.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _shareQr(BuildContext context, QrPayload payload) async {
    try {
      final bytes = await _captureReceiptBytes();
      if (bytes != null) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/receipt_${payload.purchaseId}.png');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([
          XFile(file.path, mimeType: 'image/png'),
        ], text: '${payload.storeName} - ${payload.userName}');
        return;
      }
    } catch (_) {
      // Fallback
    }
    await Share.share(payload.encode());
  }

  Future<void> _saveQrToGallery(BuildContext context, QrPayload payload) async {
    try {
      final bytes = await _captureReceiptBytes();
      if (bytes != null) {
        await Gal.putImageBytes(bytes, name: 'receipt_${payload.purchaseId}');
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text(Strings.qrSavedSuccess)));
        }
        return;
      }
    } catch (_) {
      // Fallback
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Strings.qrSaveFailed)));
    }
  }
}
