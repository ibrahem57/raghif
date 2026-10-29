import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/status_chip.dart';
import '../../core/widgets/offline_notice.dart';
import '../auth/demo_accounts.dart';
import '../../domain/models/purchase_model.dart';
import '../../domain/models/store_list_entry.dart';
import 'queue_controller.dart';
import 'queue_logic.dart';
import 'store_details_screen.dart';
import 'store_list_logic.dart';
import 'write_guard.dart';
import 'confirm_action.dart';

/// UI_SPEC.md StoreListScreen: full-width cards, single column, no grid/map.
/// Whole card is tappable when available since that's the primary action.
///
/// Buyer-specific additions:
/// - search by store name / area, plus area filter chips
/// - pin a store to keep it at the top
/// - stores the buyer actually uses (an order today, or any past purchase)
///   float up by default and get a richer card (order state, paid, last visit)
class StoreListScreen extends StatefulWidget {
  const StoreListScreen({
    super.key,
    required this.controller,
    required this.currentUser,
    this.governorate,
    this.initialArea,
  });

  final QueueController controller;
  final DemoUser currentUser;
  final String? governorate;
  final String? initialArea;

  @override
  State<StoreListScreen> createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedArea;

  @override
  void initState() {
    super.initState();
    _selectedArea = widget.initialArea;
    // The controller owns the watch (no stream lifecycle in the widget), so
    // rebuilds arrive through listenable updates.
    widget.controller.watchStoreListFor(widget.currentUser.id);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StoreListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUser.id != widget.currentUser.id) {
      _searchController.clear();
      _query = '';
      _selectedArea = widget.initialArea;
      widget.controller.watchStoreListFor(widget.currentUser.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = todayDateString();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/stitch_loaf.svg',
              width: 36,
              height: 36,
            ),
            const SizedBox(width: 8),
            const Text(Strings.appTitle),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: Strings.logout,
            onPressed: () => confirmLogout(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          if (widget.controller.storeListFailed) {
            return SingleChildScrollView(
              child: OfflineNotice(
                onRetry: () =>
                    widget.controller.watchStoreListFor(widget.currentUser.id),
              ),
            );
          }
          if (!widget.controller.storeListLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = filterStoreEntries(
            widget.controller.storeList,
            governorate: widget.governorate,
          );
          final areas = areasOf(all);
          // A selected area can disappear if its last store is removed —
          // fall back to "all" rather than showing an empty list.
          final area =
              _selectedArea != null &&
                  (areas.contains(_selectedArea) ||
                      widget.initialArea == _selectedArea)
              ? _selectedArea
              : null;
          final visible = sortStoreEntries(
            filterStoreEntries(all, query: _query, area: area),
          );

          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            Strings.storeListTitle,
                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              Text(
                                area ?? 'المناطق المتاحة',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Text(
                                '${Strings.todayLabel}: $today',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        0,
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          hintText: Strings.storeSearchHint,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'مسح البحث',
                                  onPressed: () => setState(() {
                                    _searchController.clear();
                                    _query = '';
                                  }),
                                  icon: const Icon(Icons.close),
                                ),
                        ),
                      ),
                    ),
                    if (areas.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: SizedBox(
                          height: 48,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            children: [
                              _AreaChip(
                                label: Strings.areaAllLabel,
                                selected: area == null,
                                onSelected: () =>
                                    setState(() => _selectedArea = null),
                              ),
                              for (final a in areas)
                                _AreaChip(
                                  label: a,
                                  selected: area == a,
                                  onSelected: () =>
                                      setState(() => _selectedArea = a),
                                ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: all.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Text(
                                  Strings.noStores,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            )
                          : visible.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Text(
                                  Strings.noMatchingStores,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                              ),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final entry = visible[index];
                                return _StoreCard(
                                  entry: entry,
                                  today: today,
                                  onTogglePin: () => guardWrite(
                                    context,
                                    () => widget.controller.setStorePinned(
                                      widget.currentUser.id,
                                      entry.store.id,
                                      !entry.pinned,
                                    ),
                                  ),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => StoreDetailsScreen(
                                        controller: widget.controller,
                                        currentUser: widget.currentUser,
                                        entry: entry,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
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

class _AreaChip extends StatelessWidget {
  const _AreaChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
      ),
    );
  }
}

/// One store card. Stores the buyer has history with get the richer layout:
/// a "مخبزي" tag, the order state, payment state and last-visit line.
class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.entry,
    required this.today,
    required this.onTogglePin,
    required this.onTap,
  });

  final StoreListEntry entry;
  final String today;
  final VoidCallback onTogglePin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final store = entry.store;
    final textTheme = Theme.of(context).textTheme;
    final available = store.isAvailable;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: available
                      ? AppColors.accentContainer
                      : AppColors.neutralContainer,
                  borderRadius: AppShapes.medium,
                ),
                child: Icon(
                  Icons.storefront_outlined,
                  color: available ? AppColors.bread : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(store.name, style: textTheme.titleMedium)),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                icon: Icon(
                  entry.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: entry.pinned
                      ? AppColors.accent
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                tooltip: entry.pinned ? Strings.unpinStore : Strings.pinStore,
                onPressed: onTogglePin,
              ),
            ],
          ),
          if (store.area.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              store.area,
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusChip(
              text: available
                  ? Strings.available
                  : store.isOpen
                  ? Strings.soldOut
                  : Strings.storeClosedBadge,
              tone: available
                  ? StatusTone.success
                  : store.isOpen
                  ? StatusTone.danger
                  : StatusTone.neutral,
              icon: available ? Icons.check_circle_outline : Icons.info_outline,
            ),
          ),
          if (entry.isFamiliar) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                StatusChip(
                  text: Strings.myStoreBadge,
                  tone: StatusTone.neutral,
                ),
                if (entry.hasOrderToday) ...[
                  StatusChip(
                    text: _orderLabel(entry.todayStatus!),
                    tone: _orderTone(entry.todayStatus!),
                  ),
                  const StatusChip(
                    text: Strings.paidBadge,
                    tone: StatusTone.success,
                  ),
                ],
                if (entry.lastPurchaseDate != null)
                  StatusChip(
                    text: Strings.lastPurchaseFrom(
                      purchaseDateLabel(entry.lastPurchaseDate!, today),
                    ),
                    tone: StatusTone.neutral,
                  ),
              ],
            ),
          ],
          if (available) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warmSurface,
                borderRadius: AppShapes.medium,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: AppColors.bread,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          Strings.bagsRemaining(
                            store.bagsRemaining,
                            store.dailyBagLimit,
                          ),
                          style: textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  if (store.hasPurchaseWindow) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            Strings.purchaseWindowRange(
                              store.openTime!,
                              store.closeTime!,
                            ),
                            style: textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
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
