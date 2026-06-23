import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard/teacher_dashboard_screen.dart';
import '../library/global_library_screen.dart';
import '../students/students_screen.dart';
import '../parent/parent_home_screen.dart';
import '../../../app/routes/app_router.dart';
import '../../../app/app_keys.dart';
import '../../providers/app_providers.dart';

class TeacherShellScreen extends ConsumerStatefulWidget {
  const TeacherShellScreen({super.key});

  @override
  ConsumerState<TeacherShellScreen> createState() => _TeacherShellScreenState();
}

class _TeacherShellScreenState extends ConsumerState<TeacherShellScreen> {
  int _selectedIndex = 0;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final routeName = ModalRoute.of(context)?.settings.name;
      if (routeName == AppRouter.reviewQueue) {
        _selectedIndex = 2; // Global Library
      }
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final serverHealth = ref.watch(serverHealthProvider);

    final pages = [
      const TeacherDashboardScreen(),
      const StudentsScreen(),
      const GlobalLibraryScreen(),
      RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(serverHealthProvider);
        },
        child: ServerToolsTab(
          serverHealth: serverHealth,
          onRepairPairing: () {
            Navigator.of(context).pushReplacementNamed(AppRouter.login);
          },
        ),
      ),
    ];

    // 2-level deep Unified Teacher Platform sidebar layout
    return Scaffold(
      key: AppKeys.parentHomeScreen,
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedIconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Exit to profile select',
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed(AppRouter.login);
                        },
                        icon: const Icon(Icons.exit_to_app),
                      ),
                      const Text('Exit', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Students'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_music_outlined),
                selectedIcon: Icon(Icons.library_music),
                label: Text('Global Library'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.tune_outlined),
                selectedIcon: Icon(Icons.tune),
                label: Text('Advanced'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}
