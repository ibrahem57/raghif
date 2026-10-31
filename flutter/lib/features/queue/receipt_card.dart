import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/models/purchase_model.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/status_chip.dart';

/// Opaque QR-first ticket, also captured for offline image save and share.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({
    super.key,
    required this.storeName,
    required this.purchaseId,
    required this.purchaseDate,
    required this.batchNumber,
    required this.userName,
    required this.status,
    required this.qrData,
  });

  final String storeName;
  final String purchaseId;
  final String purchaseDate;
  final int batchNumber;
  final String userName;
  final PurchaseStatus status;
  final String qrData;

  @override
  Widget build(BuildContext context) {
    final (label, tone) = switch (status) {
      PurchaseStatus.waiting => (
        Strings.statusWaitingShort,
        StatusTone.warning,
      ),
      PurchaseStatus.notified => (
        Strings.statusNotifiedShort,
        StatusTone.success,
      ),
      PurchaseStatus.collected => (
        Strings.statusCollectedShort,
        StatusTone.neutral,
      ),
    };
    return ColoredBox(
      color: AppColors.background,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxWidth.clamp(0.0, 240.0);
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Semantics(
                          label: Strings.receiptQrTitle,
                          image: true,
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            errorCorrectionLevel: QrErrorCorrectLevel.H,
                            size: (size - 24).clamp(0.0, 216.0),
                            padding: const EdgeInsets.all(16),
                            backgroundColor: Colors.white,
                            gapless: true,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    Strings.receiptQrTitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Strings.receiptQrSubtitle,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const _Perforation(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  _InfoRow(
                    label: Strings.receiptPurchaseIdLabel,
                    value: '#$purchaseId',
                  ),
                  _InfoRow(label: Strings.receiptNameLabel, value: userName),
                  _InfoRow(label: 'نقطة التوزيع', value: storeName),
                  _InfoRow(
                    label: Strings.receiptDateLabel,
                    value: purchaseDate,
                  ),
                  _InfoRow(
                    label: Strings.receiptBatchLabel,
                    value: '$batchNumber',
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: StatusChip(text: label, tone: tone),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  (constraints.maxWidth / 10).floor(),
                  (_) =>
                      Container(width: 5, height: 1, color: AppColors.border),
                ),
              ),
            ),
          ),
          for (final alignment in [Alignment.centerLeft, Alignment.centerRight])
            Align(
              alignment: alignment,
              child: FractionalTranslation(
                translation: Offset(
                  alignment == Alignment.centerLeft ? -.5 : .5,
                  0,
                ),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                    border: Border.all(color: AppColors.border),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
