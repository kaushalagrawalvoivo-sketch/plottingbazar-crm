import 'package:flutter/material.dart';

import '../customers/customer_list_screen.dart';
import '../leads/lead_list_screen.dart';
import '../reminders/follow_up_reminders_screen.dart';
import 'dashboard_screen.dart';
import 'more_menu_screen.dart';

/// App shell with a bottom navigation dock (instead of a side drawer) --
/// the primary way to move between the 5 most-used areas of the app.
/// Anything less frequently used lives one tap away under "More".
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _tabs = [
    DashboardScreen(),
    LeadListScreen(),
    CustomerListScreen(),
    FollowUpRemindersScreen(),
    MoreMenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isHome = _index == 0;
    return Scaffold(
      appBar: isHome
          ? AppBar(title: const Text('PlottingBazaar CRM'))
          : null,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Leads',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
