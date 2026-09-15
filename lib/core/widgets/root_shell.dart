import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/expenses/presentation/home_screen.dart';
import '../providers/value_notifier_provider.dart';

/// Bottom-nav shell for the 4 tabs — see frontend/docs/DESIGN_SYSTEM.md
/// "Navigation". IndexedStack (not a fresh screen per tap) so each tab
/// keeps its scroll position and in-flight state when switching away and back.
final rootTabIndexProvider = simpleValueProvider<int>(0);

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  static const _tabs = [
    HomeScreen(),
    AnalyticsScreen(),
    CategoriesScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(rootTabIndexProvider);

    return Scaffold(
      body: IndexedStack(index: index, children: _tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => ref.read(rootTabIndexProvider.notifier).set(i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), activeIcon: Icon(Icons.pie_chart), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.category_outlined), activeIcon: Icon(Icons.category), label: 'Categories'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
