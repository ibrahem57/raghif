import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/secondary_button.dart';
import '../../core/widgets/offline_notice.dart';
import '../queue/queue_controller.dart';
import 'area_screen.dart';
import 'location_logic.dart';

class GovernorateScreen extends StatelessWidget {
  const GovernorateScreen({
    super.key,
    required this.controller,
    required this.onSelected,
    required this.onBrowseAll,
    this.embedded = false,
  });

  final QueueController controller;
  final LocationSelected onSelected;
  final VoidCallback onBrowseAll;
  final bool embedded;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: embedded ? null : AppBar(title: const Text('تحديد مكان الاستلام')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.storesFailed) {
                return SingleChildScrollView(
                  child: OfflineNotice(onRetry: controller.refreshStores),
                );
              }
              final theme = Theme.of(context).textTheme;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: SvgPicture.asset(
                      'assets/images/stitch_loaf.svg',
                      width: 64,
                      height: 56,
                      excludeFromSemantics: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('اختار المحافظة', style: theme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'وين حاب تستلم الخبز؟ اختار المحافظة الأقرب إلك.',
                    style: theme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (!controller.storesLoaded)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  for (final name in governorates) ...[
                    AppCard(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AreaScreen(
                            controller: controller,
                            governorate: name,
                            onSelected: onSelected,
                            onBrowseAll: onBrowseAll,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.accentContainer,
                            foregroundColor: AppColors.accent,
                            child: Icon(Icons.location_on_outlined),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: theme.titleLarge),
                                if (controller.storesLoaded)
                                  Text(
                                    'عدد المخابز: ${storesInGovernorate(controller.stores, name).length}',
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
                  const SizedBox(height: 8),
                  SecondaryButton(
                    text: 'عرض جميع المخابز',
                    onPressed: onBrowseAll,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'المخابز التي لم تُحدد محافظتها بعد تظهر ضمن جميع المخابز.',
                    textAlign: TextAlign.center,
                    style: theme.bodyMedium,
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
