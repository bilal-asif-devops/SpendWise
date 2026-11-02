import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'wallets_screen.dart';
import 'budgets_screen.dart';
import 'activity_screen.dart';
import 'more_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(), // Tab 1: Timeline
    WalletsScreen(), // Tab 2: Wallets
    BudgetsScreen(), // Tab 3: Budgets
    ActivityScreen(), // Tab 4: Activity
    MoreScreen(), // Tab 5: More
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkCard
            : AppColors.surfaceWhite,
        indicatorColor: AppColors.accentGreen.withValues(alpha: 0.18),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon:
                Icon(Icons.receipt_long, color: AppColors.accentGreen),
            label: "Timeline",
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet,
                color: AppColors.accentGreen),
            label: "Wallets",
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings, color: AppColors.accentGreen),
            label: "Budgets",
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_outlined),
            selectedIcon:
                Icon(Icons.notifications, color: AppColors.accentGreen),
            label: "Activity",
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz, color: AppColors.accentGreen),
            label: "More",
          ),
        ],
      ),
    );
  }
}
