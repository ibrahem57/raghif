import 'package:flutter/material.dart';
import '../../core/i18n/strings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/status_chip.dart';
import '../../domain/models/purchase_model.dart';
import '../../domain/repositories/queue_repository.dart';
import '../auth/demo_accounts.dart';
import '../payment/payment_number_screen.dart';
import 'confirmation_screen.dart';
import 'queue_controller.dart';
import 'queue_logic.dart';

/// Stitch booking summary with the existing payment and daily-limit flow.
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({
    super.key,
    required this.controller,
    required this.storeId,
    required this.currentUser,
  });

  final QueueController controller;
  final String storeId;
  final DemoUser currentUser;

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  bool _isPaying = false;
  PurchaseModel? _blocker;

  String get _userId => widget.currentUser.id;

  @override
  void initState() {
    super.initState();
    _checkBlocker();
  }

  Future<void> _checkBlocker() async {
    final PurchaseModel? blocker;
    try {
      blocker = await widget.controller.blockingPurchaseFor(
        _userId,
        todayDateString(),
      );
    } on BackendUnavailableException {
      // Unknown, not "none": reserve_bag enforces one bag a day regardless.
      return;
    }
    if (mounted) {
      setState(() {
        _blocker = blocker;
      });
    }
  }

  void _startPaymentFlow() async {
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentNumberScreen(
          initialNumber:
              widget.currentUser.jawwalPayNumber ?? widget.currentUser.phone,
        ),
      ),
    );
    if (paid == true && mounted) {
      _pay();
    }
  }

  void _pay() async {
    setState(() => _isPaying = true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final date = todayDateString();
    final PurchaseModel? blocker;
    try {
      blocker = await widget.controller.blockingPurchaseFor(_userId, date);
    } on BackendUnavailableException {
      if (!mounted) return;
      setState(() => _isPaying = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Strings.offlineWriteFailed)));
      return;
    }
    if (blocker != null) {
      if (!mounted) return;
      setState(() {
        _isPaying = false;
        _blocker = blocker;
      });
      _goToConfirmation(blocker.id);
      return;
    }

    try {
      // No userId: the buyer comes from the Supabase session server-side.
      final purchase = await widget.controller.buy(
        storeId: widget.storeId,
        date: date,
      );
      if (!mounted) return;
      setState(() {
        _isPaying = false;
        _blocker = purchase;
      });
      _goToConfirmation(purchase.id);
    } on StoreSoldOutException {
      if (!mounted) return;
      setState(() => _isPaying = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Strings.soldOut)));
      Navigator.of(context).pop();
    } on BackendUnavailableException {
      // Postgres holds the bag count, so an unreachable server means no
      // reservation was made. Saying "done" here and reconciling later is
      // how two buyers end up holding the same last bag.
      if (!mounted) return;
      setState(() => _isPaying = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(Strings.offlineWriteFailed)));
    }
  }

  void _goToConfirmation(String purchaseId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmationScreen(
          controller: widget.controller,
          purchaseId: purchaseId,
          currentUser: widget.currentUser,
        ),
      ),
    );
    if (mounted) {
      _checkBlocker();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.purchaseTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final store = widget.controller.storeById(widget.storeId);
            final isAvailable = store?.isAvailable ?? false;
            final blocker = _blocker;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SummaryIcon(
                              icon: Icons.shopping_bag_outlined,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'راجع حجزك',
                                    style: textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'تأكد من المخبز قبل متابعة الدفع.',
                                    style: textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SummaryIcon(
                                  icon: Icons.storefront_outlined,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'مخبز الاستلام',
                                        style: textTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        store?.name ?? '',
                                        style: textTheme.titleLarge,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: StatusChip(
                                text: isAvailable
                                    ? Strings.available
                                    : Strings.soldOut,
                                tone: isAvailable
                                    ? StatusTone.success
                                    : StatusTone.danger,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              Strings.bagsRemaining(
                                store?.bagsRemaining ?? 0,
                                store?.dailyBagLimit ?? 0,
                              ),
                              style: textTheme.bodyLarge,
                            ),
                            if (store?.hasPurchaseWindow ?? false) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                Strings.purchaseWindowRange(
                                  store!.openTime!,
                                  store.closeTime!,
                                ),
                                style: textTheme.bodyMedium,
                              ),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.lg,
                              ),
                              child: Divider(
                                height: 1,
                                color: AppColors.border,
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/images/stitch_bread.png',
                                height: 152,
                                fit: BoxFit.cover,
                                excludeFromSemantics: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (blocker != null)
                        AppCard(
                          child: Text(
                            blocker.storeId == widget.storeId
                                ? Strings.dailyLimitReached
                                : Strings.dailyLimitReachedOtherStore(
                                    blocker.storeName ??
                                        widget.controller
                                            .storeById(blocker.storeId)
                                            ?.name ??
                                        '',
                                  ),
                            style: textTheme.titleMedium,
                          ),
                        )
                      else
                        AppCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SummaryIcon(
                                icon: Icons.account_balance_wallet_outlined,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'الدفع عبر جوال باي',
                                      style: textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'ستؤكد رقم المحفظة ورمز الدفع في الخطوة التالية.',
                                      style: textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.lg),
                      if (blocker != null)
                        PrimaryButton(
                          text: Strings.viewOrder,
                          onPressed: () => _goToConfirmation(blocker.id),
                        )
                      else
                        PrimaryButton(
                          text: Strings.payButton,
                          loading: _isPaying,
                          onPressed: _startPaymentFlow,
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      SecondaryButton(
                        text: Strings.back,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SummaryIcon extends StatelessWidget {
  const _SummaryIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, size: 26, color: AppColors.accent),
    ),
  );
}
