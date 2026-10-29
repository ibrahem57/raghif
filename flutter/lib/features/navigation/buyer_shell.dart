import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../domain/repositories/notification_repository.dart';
import '../account/account_screen.dart';
import '../auth/demo_accounts.dart';
import '../locations/governorate_screen.dart';
import '../queue/buyer_home_screen.dart';
import '../queue/queue_controller.dart';
import 'inbox_navigation.dart';
import 'pickup_navigation.dart';

class BuyerShell extends StatefulWidget {
  const BuyerShell({
    super.key,
    required this.controller,
    required this.currentUser,
    this.notifications,
  });
  final QueueController controller;
  final DemoUser currentUser;
  final NotificationRepository? notifications;
  @override
  State<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends State<BuyerShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _index == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && _index != 0) setState(() => _index = 0);
    },
    child: Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/stitch_loaf.svg',
              width: 32,
              height: 32,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: 10),
            Text(['الرئيسية', 'حجزي', 'حسابي'][_index]),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'الإشعارات',
            onPressed: () => openInbox(
              context,
              widget.controller,
              widget.currentUser,
              widget.notifications,
            ),
            icon: const Icon(Icons.notifications_outlined),
          ),
        ],
      ),
      body: switch (_index) {
        0 => GovernorateScreen(
          controller: widget.controller,
          embedded: true,
          onSelected: (province, area) => openStoreResults(
            context,
            widget.controller,
            widget.currentUser,
            governorate: province,
            area: area,
          ),
          onBrowseAll: () =>
              openStoreResults(context, widget.controller, widget.currentUser),
        ),
        1 => BuyerHomeScreen(
          controller: widget.controller,
          currentUser: widget.currentUser,
          embedded: true,
        ),
        _ => const AccountScreen(embedded: true),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'حجزي',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    ),
  );
}
