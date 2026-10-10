import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_environment.dart';
import '../../../auth/domain/auth_session.dart';
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
    ProfilePage(
      session: widget.session,
      refreshSession: widget.renewSession,
      onLogout: widget.onLogout,
    ),
  ];

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        IndexedStack(index: _selectedIndex, children: _pages),
        if (MediaQuery.viewInsetsOf(context).bottom == 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 16),
              child: Center(
                heightFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: FloatingPatientNavigation(
                      selectedIndex: _selectedIndex,
                      onSelected: (index) =>
                          setState(() => _selectedIndex = index),
                      onComingSoon: _showComingSoon,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class FloatingPatientNavigation extends StatelessWidget {
  const FloatingPatientNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.onComingSoon,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<String> onComingSoon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pillColor = theme.brightness == Brightness.light
        ? Colors.white
        : scheme.surfaceContainerHigh;

    return SizedBox(
      width: 440,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned.fill(
            top: 10,
            child: Material(
              elevation: 5,
              shadowColor: Colors.black26,
              color: pillColor,
              borderRadius: BorderRadius.circular(30),
              child: Row(
                children: [
                  Expanded(
                    child: _SideDestination(
                      label: 'Hoje',
                      icon: Icons.today_outlined,
                      selectedIcon: Icons.today_rounded,
                      selected: selectedIndex == 0,
                      onTap: () => onSelected(0),
                    ),
                  ),
                  Expanded(
                    child: _SideDestination(
                      label: 'Semana',
                      icon: Icons.calendar_view_week_outlined,
                      selectedIcon: Icons.calendar_view_week_rounded,
                      selected: selectedIndex == 1,
                      onTap: () => onSelected(1),
                    ),
                  ),
                  const SizedBox(width: 64),
                  Expanded(
                    child: _SideDestination(
                      label: 'Compras',
                      icon: Icons.shopping_bag_outlined,
                      selectedIcon: Icons.shopping_bag_rounded,
                      selected: false,
                      onTap: () =>
                          onComingSoon('Compras estarão disponíveis em breve.'),
                    ),
                  ),
                  Expanded(
                    child: _SideDestination(
                      label: 'Perfil',
                      icon: Icons.person_outline_rounded,
                      selectedIcon: Icons.person_rounded,
                      selected: selectedIndex == 2,
                      onTap: () => onSelected(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -6),
            child: Semantics(
              label: 'Adicionar, em breve',
              button: true,
              child: Tooltip(
                message: 'Adicionar (em breve)',
                excludeFromSemantics: true,
                child: SizedBox(
                  width: 64,
                  height: 72,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Material(
                        elevation: 3,
                        shadowColor: scheme.primary.withValues(alpha: 0.25),
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(18),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => onComingSoon(
                            'Esta função estará disponível em breve.',
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 27,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideDestination extends StatelessWidget {
  const _SideDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? selectedIcon : icon,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  height: 1.05,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
