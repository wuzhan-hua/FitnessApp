import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/providers.dart';
import '../pages/calendar_page.dart';
import '../pages/diet_page.dart';
import '../pages/exercise_library_page.dart';
import '../pages/home_page.dart';
import '../pages/profile_page.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    HomePage(),
    DietPage(),
    CalendarPage(),
    ExerciseLibraryPage(
      args: ExerciseLibraryPageArgs(mode: ExerciseLibraryMode.browse),
    ),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    Future<void>(() {
      ref.read(homeSnapshotProvider);
      ref.read(foodLibraryProvider);
      ref.read(dailyDietSummaryProvider(DateTime.now()));
      final month = ref.read(calendarMonthProvider);
      ref.read(sessionsByMonthProvider(month));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (value) => setState(() => _currentIndex = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '运动',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: '饮食',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '日历',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: '动作库',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
