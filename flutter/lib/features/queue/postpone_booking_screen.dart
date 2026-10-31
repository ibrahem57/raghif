import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/secondary_button.dart';
import '../../domain/models/purchase_model.dart';
import '../../domain/repositories/queue_repository.dart';
import 'queue_controller.dart';

class PostponeBookingScreen extends StatefulWidget {
  const PostponeBookingScreen({
    super.key,
    required this.controller,
    required this.purchase,
  });
  final QueueController controller;
  final PurchaseModel purchase;

  @override
  State<PostponeBookingScreen> createState() => _PostponeBookingScreenState();
}

class _PostponeBookingScreenState extends State<PostponeBookingScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final moved = await widget.controller.postponePurchase(
        widget.purchase.id,
      );
      if (mounted) Navigator.of(context).pop(moved);
    } on PostponeRejectedException catch (e) {
      if (mounted) {
        setState(() {
          _error = switch (e.reason) {
            'already reserved a bag tomorrow' =>
              'لديك حجز غداً. لا يمكن حجز أكثر من ربطة في اليوم.',
            'tomorrow capacity exhausted' =>
              'اكتملت سعة المخبز ليوم غد. بقي موعد حجزك كما هو.',
            'already postponed' =>
              'تم تأجيل هذا الحجز سابقاً. التأجيل متاح مرة واحدة فقط.',
            _ => 'هذا الحجز غير مؤهل للتأجيل. حدّث بيانات حجزك وحاول مجدداً.',
          };
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تأجيل الحجز. تحقق من الاتصال وحاول مجدداً.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    final tomorrow = DateTime.parse(
      p.purchaseDate,
    ).add(const Duration(days: 1)).toIso8601String().substring(0, 10);
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تأجيل الحجز'),
          automaticallyImplyLeading: !_saving,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.event_repeat_outlined,
                      size: 64,
                      color: AppColors.accent,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'نؤجل حجزك إلى الغد؟',
                      style: text.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    AppCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            p.storeName ??
                                widget.controller.storeById(p.storeId)?.name ??
                                'المخبز نفسه',
                            style: text.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'الموعد الحالي: ${p.purchaseDate}',
                            style: text.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'الموعد الجديد: $tomorrow',
                            style: text.titleMedium,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'لن يتم خصم أي مبلغ إضافي',
                            style: text.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'التأجيل متاح مرة واحدة، ويحتسب من حصتك وسعة المخبز ليوم غد. سيبدأ الحجز بانتظار دفعة جديدة، دون ضمان وقت استلام.',
                      style: text.bodyLarge,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: text.bodyLarge?.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    PrimaryButton(
                      text: 'تأكيد التأجيل',
                      loading: _saving,
                      onPressed: _saving ? null : _confirm,
                    ),
                    const SizedBox(height: 12),
                    SecondaryButton(
                      text: 'الاحتفاظ بموعدي',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
