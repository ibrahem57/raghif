import 'package:flutter/material.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/offline_notice.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/number_stepper.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../domain/models/purchase_model.dart';
import 'qr_scanner_screen.dart';
import '../../domain/models/store_model.dart';
import 'queue_controller.dart';
import 'queue_logic.dart';
import 'write_guard.dart';

/// Batch headers retain labelled progress. The notify action stays pinned
/// when height allows and scrolls with content in compact windows.
///
/// Pickup additions: buyer rows carry national ID + phone, a live filter
/// finds a buyer by ID/phone suffix, and an AppBar scan action opens the QR
/// redemption scanner (#28).
class OwnerQueueScreen extends StatefulWidget {
  const OwnerQueueScreen({
    super.key,
    required this.controller,
    required this.storeId,
  });

  final QueueController controller;
  final dynamic storeId;

  @override
  State<OwnerQueueScreen> createState() => _OwnerQueueScreenState();
}

class _OwnerQueueScreenState extends State<OwnerQueueScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(PurchaseModel p) {
    final q = _query.trim();
    if (q.isEmpty) return true;
    final digitsOnly = q.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isNotEmpty) {
      final idDigits = (p.userNationalId ?? '').replaceAll(RegExp(r'\D'), '');
      final phoneDigits = (p.userPhone ?? '').replaceAll(RegExp(r'\D'), '');
      if (idDigits.endsWith(digitsOnly) || phoneDigits.endsWith(digitsOnly)) {
        return true;
      }
    }
    return (p.userName ?? '').contains(q);
  }

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(
          controller: widget.controller,
          storeId: widget.storeId,
        ),
      ),
    );
  }

  /// Releasing a batch notifies real buyers, so the owner confirms first — and
  /// if people from earlier batches never picked up, the dialog says how many
  /// instead of silently calling another batch on top of them.
  Future<void> _confirmNotify(
    int batch,
    List<PurchaseModel> queue,
    String date,
  ) async {
    final outstanding = outstandingBefore(batch, queue);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.notifyConfirmTitle),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Strings.notifyConfirmBody(batch)),
            if (outstanding > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                Strings.notifyOutstandingWarning(outstanding),
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(Strings.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(Strings.notifyConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      await guardWrite(
        context,
        () => widget.controller.notifyNextBatch(widget.storeId, date),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = todayDateString();
    final searching = _query.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.textScalerOf(context).scale(20) > 26
            ? 96
            : 64,
        title: Text(Strings.buyerQueueTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: Strings.scanQrTitle,
            onPressed: _openScanner,
          ),
        ],
      ),
      body: StreamBuilder<List<PurchaseModel>>(
        stream: widget.controller.watchQueueForStore(widget.storeId, date),
        builder: (context, snapshot) {
          final store = widget.controller.storeById(widget.storeId);
          final queue = snapshot.data ?? [];
          final visible = searching ? queue.where(_matches).toList() : queue;
          final grouped = <int, List<PurchaseModel>>{};
          for (final p in visible) {
            grouped.putIfAbsent(p.batchNumber, () => []).add(p);
          }
          final batchNumbers = grouped.keys.toList()..sort();
          // Tallies for the batch headers ("picked / awaiting / not called"),
          // always from the FULL queue so a search can't change the numbers.
          final progress = {
            for (final p in batchProgressForQueue(queue)) p.batch: p,
          };
          // Notify decision always uses the FULL queue; the button is hidden
          // while searching so a lookup can't accidentally release a batch.
          final nextBatch = searching ? null : nextBatchToNotify(queue);

          final entries = <Widget>[
            AppCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.background,
                    foregroundColor: AppColors.accent,
                    child: Icon(Icons.bakery_dining_outlined),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      store?.name ?? '',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (store != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _BatchSizeControl(
                controller: widget.controller,
                storeId: widget.storeId,
                store: store,
                date: date,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: Strings.searchBuyerHint,
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (snapshot.hasError)
              const OfflineNotice()
            else if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if (queue.isEmpty || visible.isEmpty)
              AppCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      color: AppColors.accent,
                      size: 40,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      queue.isEmpty
                          ? Strings.queueEmpty
                          : Strings.buyerSearchNoResults,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            for (final batch in batchNumbers) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Strings.batchLabel(batch),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (progress[batch] != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        Strings.batchSummary(
                          progress[batch]!.picked,
                          progress[batch]!.awaitingPickup,
                          progress[batch]!.waiting,
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
              for (final purchase in grouped[batch]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _BuyerRow(
                    purchase: purchase,
                    onToggleArrival: () => guardWrite(
                      context,
                      () => widget.controller.collectPurchase(purchase.id),
                    ),
                  ),
                ),
            ],
          ];
          final notify = nextBatch == null
              ? null
              : PrimaryButton(
                  text: Strings.notifyNextBatch(nextBatch),
                  onPressed: () => _confirmNotify(nextBatch, queue, date),
                );
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxHeight < 460 ||
                        MediaQuery.textScalerOf(context).scale(15) > 20;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ListView.builder(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount:
                                entries.length +
                                (compact && notify != null ? 1 : 0),
                            itemBuilder: (context, index) =>
                                index < entries.length
                                ? entries[index]
                                : Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.md,
                                    ),
                                    child: notify,
                                  ),
                          ),
                        ),
                        if (notify != null && !compact)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: notify,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BuyerRow extends StatelessWidget {
  const _BuyerRow({required this.purchase, required this.onToggleArrival});

  final PurchaseModel purchase;
  final VoidCallback onToggleArrival;

  @override
  Widget build(BuildContext context) {
    final tone = switch (purchase.status) {
      PurchaseStatus.notified => StatusTone.success,
      PurchaseStatus.collected => StatusTone.neutral,
      PurchaseStatus.waiting => StatusTone.warning,
    };
    final statusText = switch (purchase.status) {
      PurchaseStatus.notified => Strings.statusNotifiedShort,
      PurchaseStatus.collected => Strings.statusCollectedShort,
      PurchaseStatus.waiting => Strings.statusWaitingShort,
    };

    final meta = [
      if (purchase.userNationalId != null &&
          purchase.userNationalId!.isNotEmpty)
        '${Strings.idShortLabel}: ${purchase.userNationalId}',
      if (purchase.userPhone != null && purchase.userPhone!.isNotEmpty)
        '${Strings.phoneShortLabel}: ${purchase.userPhone}',
    ].join('  ·  ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.accent,
                child: Icon(Icons.person_outline),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      purchase.userName ??
                          purchase.userPhone ??
                          purchase.userId.toString(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(meta, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(text: statusText, tone: tone),
              Text(
                formatReadyTime(purchase.createdAtMillis),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          if (purchase.status != PurchaseStatus.waiting) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              onPressed: onToggleArrival,
              text: purchase.status == PurchaseStatus.notified
                  ? Strings.markReceived
                  : Strings.undoReceived,
            ),
          ],
        ],
      ),
    );
  }
}

/// Batch size groups this queue into notify-able chunks; it lives here
/// (rather than the store dashboard) since it only makes sense next to
/// the queue it groups.
class _BatchSizeControl extends StatefulWidget {
  const _BatchSizeControl({
    required this.controller,
    required this.storeId,
    required this.store,
    required this.date,
  });

  final QueueController controller;
  final dynamic storeId;
  final StoreModel store;
  final String date;

  @override
  State<_BatchSizeControl> createState() => _BatchSizeControlState();
}

class _BatchSizeControlState extends State<_BatchSizeControl>
    with AutomaticKeepAliveClientMixin {
  late int _batchSize = widget.store.batchSize;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Strings.batchSizeLabel,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: NumberStepper(
              value: _batchSize,
              onChanged: (v) => setState(() => _batchSize = v),
              decrementLabel: Strings.decreaseValue,
              incrementLabel: Strings.increaseValue,
              min: 1,
            ),
          ),
          if (_batchSize != widget.store.batchSize) ...[
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              text: Strings.saveBatchSize,
              onPressed: () => guardWrite(
                context,
                () => widget.controller.saveAllocation(
                  widget.storeId,
                  dailyBagLimit: widget.store.dailyBagLimit,
                  batchSize: _batchSize,
                  today: widget.date,
                  openTime: widget.store.openTime,
                  closeTime: widget.store.closeTime,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
