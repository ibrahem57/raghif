import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/offline_notice.dart';
import '../queue/queue_controller.dart';
import 'location_logic.dart';

class AreaScreen extends StatefulWidget {
  const AreaScreen({
    super.key,
    required this.controller,
    required this.governorate,
    required this.onSelected,
    required this.onBrowseAll,
  });
  final QueueController controller;
  final String governorate;
  final LocationSelected onSelected;
  final VoidCallback onBrowseAll;
  @override
  State<AreaScreen> createState() => _AreaScreenState();
}

class _AreaScreenState extends State<AreaScreen> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('محافظة ${widget.governorate}')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              if (widget.controller.storesFailed) {
                return SingleChildScrollView(
                  child: OfflineNotice(
                    onRetry: widget.controller.refreshStores,
                  ),
                );
              }
              final stores = storesInGovernorate(
                widget.controller.stores,
                widget.governorate,
              );
              final areas =
                  stores
                      .map((s) => s.area.trim())
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .where((s) => s.contains(_search.text.trim()))
                      .toList()
                    ..sort();
              final theme = Theme.of(context).textTheme;
              return ListView(
                padding: const EdgeInsets.all(20),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Text('اختار المنطقة', style: theme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'حدد منطقتك لعرض المخابز الموجودة فيها.',
                    style: theme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'ابحث عن المنطقة',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (!widget.controller.storesLoaded)
                    const Center(child: CircularProgressIndicator())
                  else if (areas.isEmpty)
                    AppCard(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.travel_explore,
                            size: 40,
                            color: AppColors.accent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _search.text.trim().isEmpty
                                ? 'لا توجد مناطق مسجلة هنا بعد'
                                : 'لم نجد المنطقة المطلوبة',
                            textAlign: TextAlign.center,
                            style: theme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'يمكنك الرجوع لتغيير المحافظة أو عرض جميع المخابز.',
                            textAlign: TextAlign.center,
                            style: theme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  for (final area in areas) ...[
                    AppCard(
                      onTap: () => widget.onSelected(widget.governorate, area),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.accentContainer,
                            foregroundColor: AppColors.accent,
                            child: Icon(Icons.place_outlined),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(area, style: theme.titleLarge),
                                Text(
                                  'عدد المخابز: ${stores.where((s) => s.area.trim() == area).length}',
                                  style: theme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_left,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 20),
                  SecondaryButton(
                    text: 'عرض جميع المخابز',
                    onPressed: widget.onBrowseAll,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}
