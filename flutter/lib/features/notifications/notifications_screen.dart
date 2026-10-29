import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.repository,
    required this.onOpenPurchase,
  });

  final NotificationRepository repository;
  final void Function(String purchaseId) onOpenPurchase;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  bool _failed = false;
  bool _saving = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _items = [];
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final items = await widget.repository.fetchNotifications();
      if (!mounted || request != _request) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _read({AppNotification? item}) async {
    if (_saving || _loading) return;
    final repository = widget.repository;
    setState(() => _saving = true);
    // Only mark notifications that existed at the start of the operation.
    final ids = item == null ? _items.map((n) => n.id).toSet() : {item.id};
    try {
      if (item == null) {
        await repository.markAllRead();
      } else if (!item.isRead) {
        await repository.markRead(item.id);
      }
      if (!mounted || repository != widget.repository) return;
      setState(() {
        _items = _items
            .map((n) => ids.contains(n.id) ? n.asRead(DateTime.now()) : n)
            .toList();
      });
    } catch (_) {
      if (!mounted || repository != widget.repository) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ حالة القراءة. حاول مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (mounted && item != null && repository == widget.repository) {
      widget.onOpenPurchase(item.purchaseId);
    }
  }

  Widget _button(String label, VoidCallback? onPressed) => TextButton(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      textStyle: AppTypography.labelMedium,
      foregroundColor: AppColors.accent,
    ),
    onPressed: onPressed,
    child: Text(label),
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('الإشعارات')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _saving ? () async {} : _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              const Text('آخر أخبار حجزك', style: AppTypography.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'تابع تأكيد الحجز وموعد الاستلام وأي تأجيل هنا.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'جارٍ تحميل الإشعارات',
                    ),
                  ),
                )
              else if (_failed)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'تعذر تحميل الإشعارات',
                        style: AppTypography.titleMedium,
                      ),
                      const Text(
                        'تحقق من الاتصال ثم حاول مرة أخرى.',
                        style: AppTypography.bodyMedium,
                      ),
                      _button('إعادة المحاولة', _load),
                    ],
                  ),
                )
              else if (_items.isEmpty)
                const AppCard(
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_none_rounded,
                        size: 48,
                        color: AppColors.accent,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'لا توجد إشعارات بعد',
                        style: AppTypography.titleMedium,
                      ),
                      Text(
                        'ستظهر تحديثات حجزك هنا عند وصولها.',
                        style: AppTypography.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: _button(
                    'قراءة الكل',
                    _saving || !_items.any((n) => !n.isRead)
                        ? null
                        : () => _read(),
                  ),
                ),
                if (_saving)
                  const LinearProgressIndicator(
                    semanticsLabel: 'جارٍ حفظ حالة القراءة',
                  ),
                for (final item in _items) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!item.isRead)
                          const Text(
                            'غير مقروء',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(item.title, style: AppTypography.titleMedium),
                        const SizedBox(height: 8),
                        Text(item.body, style: AppTypography.bodyLarge),
                        const SizedBox(height: 8),
                        Text(
                          _date(item.createdAt),
                          style: AppTypography.bodyMedium,
                        ),
                        _button(
                          'عرض الحجز',
                          _saving ? null : () => _read(item: item),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );

  String _date(DateTime time) {
    final local = time.toLocal();
    return '${local.day}/${local.month}/${local.year} · ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
