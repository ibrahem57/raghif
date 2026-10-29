import 'package:flutter/material.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../domain/models/purchase_model.dart';
import '../../domain/models/store_list_entry.dart';
import '../auth/demo_accounts.dart';
import 'confirmation_screen.dart';
import 'purchase_screen.dart';
import 'queue_controller.dart';
import 'queue_logic.dart';
import 'store_list_logic.dart';
import 'write_guard.dart';

/// Store details — the hub the buyer lands on from the store list.
///
/// Shows who the store is, whether it can be bought from right now, this
/// buyer's own order at it today (with a way back to the receipt QR), their
/// last visit, and the pin toggle. The buy action on top of that goes to
/// [PurchaseScreen], so availability is re-checked at purchase time.
class StoreDetailsScreen extends StatefulWidget {
  const StoreDetailsScreen({
    super.key,
    required this.controller,
    required this.currentUser,
    required this.entry,
  });

  final QueueController controller;
  final DemoUser currentUser;

  /// Snapshot from the list; live values are re-read from the controller so
  /// pin toggles and stock changes show up immediately.
  final StoreListEntry entry;

  @override
  State<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  @override
  void initState() {
    super.initState();
    // In case the screen is opened without the list having been watched.
    widget.controller.watchStoreListFor(widget.currentUser.id);
  }

  StoreListEntry get _entry {
    for (final e in widget.controller.storeList) {
      if (e.store.id == widget.entry.store.id) return e;
    }
    return widget.entry;
  }

  void _openPurchase() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PurchaseScreen(
          controller: widget.controller,
          storeId: widget.entry.store.id,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _openReceipt(String purchaseId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmationScreen(
          controller: widget.controller,
          purchaseId: purchaseId,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = todayDateString();
    return Scaffold(
      appBar: AppBar(title: Text(Strings.storeDetailsTitle)),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => PrimaryButton(
              text: Strings.reserveBagButton,
              onPressed: _entry.store.isAvailable ? _openPurchase : null,
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final entry = _entry;
          final store = entry.store;

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: Image.asset(
                        'assets/images/stitch_bread.png',
                        height: 256,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _IdentityCard(
                      entry: entry,
                      onTogglePin: () => guardWrite(
                        context,
                        () => widget.controller.setStorePinned(
                          widget.currentUser.id,
                          store.id,
                          !entry.pinned,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _AvailabilityCard(entry: entry),
                    if (entry.hasOrderToday) ...[
                      const SizedBox(height: AppSpacing.md),
                      _MyOrderCard(
                        entry: entry,
                        onShowReceipt: entry.todayPurchaseId == null
                            ? null
                            : () => _openReceipt(entry.todayPurchaseId!),
                      ),
                    ],
                    if (entry.lastPurchaseDate != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _HistoryCard(entry: entry, today: today),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.entry, required this.onTogglePin});

  final StoreListEntry entry;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    final store = entry.store;
    final textTheme = Theme.of(context).textTheme;
    final available = store.isAvailable;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(store.name, style: textTheme.titleLarge)),
              StatusChip(
                text: available
                    ? Strings.available
                    : store.isOpen
                    ? Strings.soldOut
                    : Strings.storeClosedBadge,
                tone: available ? StatusTone.success : StatusTone.danger,
              ),
            ],
          ),
          if (store.area.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(store.area, style: textTheme.bodyMedium)),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: onTogglePin,
              icon: Icon(
                entry.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: entry.pinned ? AppColors.accent : null,
              ),
              label: Text(entry.pinned ? Strings.unpinStore : Strings.pinStore),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.entry});

  final StoreListEntry entry;

  @override
  Widget build(BuildContext context) {
    final store = entry.store;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (store.isAvailable) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow =
                    constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final stock = _AvailabilityTile(
                  icon: Icons.bakery_dining_outlined,
                  value: '${store.bagsRemaining}',
                  label: Strings.bagsRemaining(
                    store.bagsRemaining,
                    store.dailyBagLimit,
                  ),
                  emphasis: true,
                );
                final window = _AvailabilityTile(
                  icon: Icons.schedule,
                  value: store.closeTime ?? '—',
                  label: store.hasPurchaseWindow
                      ? Strings.purchaseWindowRange(
                          store.openTime!,
                          store.closeTime!,
                        )
                      : 'مواعيد الحجز غير محددة',
                );
                return narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [stock, const SizedBox(height: 12), window],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: stock),
                          const SizedBox(width: 12),
                          Expanded(child: window),
                        ],
                      );
              },
            ),
          ] else
            Text(
              store.isOpen ? Strings.soldOut : Strings.storeClosedLabel,
              style: textTheme.bodyLarge,
            ),
        ],
      ),
    );
  }
}

class _AvailabilityTile extends StatelessWidget {
  const _AvailabilityTile({
    required this.icon,
    required this.value,
    required this.label,
    this.emphasis = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.warmSurface,
      borderRadius: AppShapes.medium,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Icon(icon, size: 24, color: AppColors.bread),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: emphasis ? AppColors.accent : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _MyOrderCard extends StatelessWidget {
  const _MyOrderCard({required this.entry, required this.onShowReceipt});

  final StoreListEntry entry;
  final VoidCallback? onShowReceipt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = entry.todayStatus!;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(Strings.myOrderTodayTitle, style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              StatusChip(text: _orderLabel(status), tone: _orderTone(status)),
              const StatusChip(
                text: Strings.paidBadge,
                tone: StatusTone.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SecondaryButton(
            text: Strings.showReceiptButton,
            onPressed: onShowReceipt,
          ),
        ],
      ),
    );
  }

  String _orderLabel(PurchaseStatus status) => switch (status) {
    PurchaseStatus.waiting => Strings.orderWaiting,
    PurchaseStatus.notified => Strings.orderReady,
    PurchaseStatus.collected => Strings.orderCollected,
  };

  StatusTone _orderTone(PurchaseStatus status) => switch (status) {
    PurchaseStatus.waiting => StatusTone.warning,
    PurchaseStatus.notified => StatusTone.success,
    PurchaseStatus.collected => StatusTone.neutral,
  };
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.today});

  final StoreListEntry entry;
  final String today;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(
        Strings.lastPurchaseFrom(
          purchaseDateLabel(entry.lastPurchaseDate!, today),
        ),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
