import 'package:flutter/material.dart';
import '../auth/demo_accounts.dart';
import '../locations/governorate_screen.dart';
import '../queue/queue_controller.dart';
import '../queue/store_list_screen.dart';

void openStoreResults(
  BuildContext context,
  QueueController controller,
  DemoUser user, {
  String? governorate,
  String? area,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => StoreListScreen(
        controller: controller,
        currentUser: user,
        governorate: governorate,
        initialArea: area,
      ),
    ),
  );
}

void openPickupSelection(
  BuildContext context,
  QueueController controller,
  DemoUser user,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => GovernorateScreen(
        controller: controller,
        onSelected: (province, area) => openStoreResults(
          context,
          controller,
          user,
          governorate: province,
          area: area,
        ),
        onBrowseAll: () => openStoreResults(context, controller, user),
      ),
    ),
  );
}
