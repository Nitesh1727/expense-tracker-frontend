import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/categories/presentation/categories_screen.dart';
import '../../features/categories/presentation/widgets/category_form_sheet.dart';
import '../../features/expenses/presentation/home_screen.dart';
import '../../features/expenses/presentation/widgets/expense_form_sheet.dart';
import '../providers/value_notifier_provider.dart';
import '../theme/app_motion.dart';
import 'app_bar_title.dart';
import 'avatar_glyph.dart';

/// Shell for the 3 main tabs — see frontend/docs/DESIGN_SYSTEM.md
/// "Navigation". Profile is deliberately not a 4th tab: it's a top-right
/// avatar button (pushed as a normal route), which is why this shell owns
/// one shared AppBar/FAB instead of each tab screen having its own — the
/// title and FAB action swap per page, but the chrome around them doesn't.
final rootTabIndexProvider = simpleValueProvider<int>(0);

const _tabTitles = ['Home', 'Analytics', 'Categories'];
const _tabs = [HomeScreen(), AnalyticsScreen(), CategoriesScreen()];

class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: ref.read(rootTabIndexProvider));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNavTap(int index) {
    ref.read(rootTabIndexProvider.notifier).set(index);
    _pageController.animateToPage(index, duration: AppMotion.standard, curve: AppMotion.standardCurve);
  }

  void _onPageChanged(int index) {
    ref.read(rootTabIndexProvider.notifier).set(index);
  }

  void _onFabPressed(int index) {
    if (index == 0) showExpenseFormSheet(context);
    if (index == 2) showCategoryFormSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(rootTabIndexProvider);
    final user = ref.watch(authControllerProvider).value;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: AppBarTitle(_tabTitles[index]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
                child: AvatarGlyph(avatar: user?.avatar, name: user?.name, size: 36, color: colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _tabs,
      ),
      floatingActionButton: index == 1
          ? null
          : FloatingActionButton(onPressed: () => _onFabPressed(index), child: const Icon(Icons.add)),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), activeIcon: Icon(Icons.pie_chart), label: 'Analytics'),
          BottomNavigationBarItem(icon: Icon(Icons.category_outlined), activeIcon: Icon(Icons.category), label: 'Categories'),
        ],
      ),
    );
  }
}
