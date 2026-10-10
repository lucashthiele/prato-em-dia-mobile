import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_environment.dart';
import '../../../auth/domain/auth_session.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_repository_impl.dart';
import '../../../catalog/presentation/pages/catalog_screen.dart';
import '../../../planning/data/weekly_planning_api.dart';
import '../../../planning/data/weekly_planning_repository_impl.dart';
import '../../../planning/presentation/pages/weekly_planning_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import 'today_page.dart';

/// The patient's available MVP destinations.
class PatientShell extends StatefulWidget {
  const PatientShell({
    required this.session,
    required this.renewSession,
    required this.onLogout,
    super.key,
  });

  final AuthSession session;
  final Future<AuthSession?> Function() renewSession;
  final Future<void> Function() onLogout;

  @override
  State<PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<PatientShell> {
  int _selectedIndex = 0;
  late final List<Widget> _pages = [
    TodayPage(
      session: widget.session,
      renewSession: widget.renewSession,
      onLogout: widget.onLogout,
    ),
    WeeklyPlanningPage(
      repository: WeeklyPlanningRepositoryImpl(
        WeeklyPlanningApi(
          Dio(
            BaseOptions(
              baseUrl: AppEnvironment.apiBaseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
              headers: const {'Accept': 'application/json'},
            ),
          ),
          accessToken: widget.session.accessToken,
          tokenType: widget.session.tokenType,
          renewCredentials: () async {
            final session = await widget.renewSession();
            return session == null
                ? null
                : (
                    accessToken: session.accessToken,
                    tokenType: session.tokenType,
                  );
          },
        ),
      ),
    ),
    CatalogScreen(
      repository: CatalogRepositoryImpl(
        CatalogApi(
          Dio(
            BaseOptions(
              baseUrl: AppEnvironment.apiBaseUrl,
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
              headers: const {'Accept': 'application/json'},
            ),
          ),
          widget.session,
          widget.renewSession,
        ),
      ),
    ),
    ProfilePage(
      session: widget.session,
      refreshSession: widget.renewSession,
      onLogout: widget.onLogout,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _selectedIndex, children: _pages),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.today_outlined),
          selectedIcon: Icon(Icons.today_rounded),
          label: 'Hoje',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_view_week_outlined),
          selectedIcon: Icon(Icons.calendar_view_week_rounded),
          label: 'Minha semana',
        ),
        NavigationDestination(
          icon: Icon(Icons.restaurant_menu_outlined),
          selectedIcon: Icon(Icons.restaurant_menu_rounded),
          label: 'Catálogo',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline_rounded),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Perfil',
        ),
      ],
    ),
  );
}
