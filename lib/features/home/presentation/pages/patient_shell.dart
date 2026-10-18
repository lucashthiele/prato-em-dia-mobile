import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/app_environment.dart';
import '../../../auth/domain/auth_session.dart';
import '../../../food_log/presentation/pages/food_log_page.dart';
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
    TodayPage(session: widget.session, renewSession: widget.renewSession),
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
      onOpenMeal: (meal) async {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => FoodLogPage(
              mealId: meal.id,
              mealName: meal.name,
              date:
                  '${meal.date.year.toString().padLeft(4, '0')}-${meal.date.month.toString().padLeft(2, '0')}-${meal.date.day.toString().padLeft(2, '0')}',
              mealType: meal.mealType,
              plannedTime: meal.time,
              session: widget.session,
              renewSession: widget.renewSession,
            ),
          ),
        );
      },
    ),
    ProfilePage(
      session: widget.session,
      refreshSession: widget.renewSession,
      onLogout: widget.onLogout,
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    // Content scrolls under the floating bar; pages pad their lists by the
    // bottom inset this exposes.
    extendBody: true,
    body: IndexedStack(index: _selectedIndex, children: _pages),
    bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
        ? null
        : PatientNavigationBar(
            selectedIndex: _selectedIndex,
            onSelected: (index) => setState(() => _selectedIndex = index),
          ),
  );
}

class FloatingPatientNavigation extends StatelessWidget {
  const FloatingPatientNavigation({
    required this.selectedIndex,
    required this.onSelected,
    this.glass = false,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Frosted, translucent look (approximates Liquid Glass) for iOS < 26.
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const destinations = [
      ('Início', Icons.adjust_rounded, Icons.adjust_rounded),
      ('Plano', Icons.calendar_today_outlined, Icons.calendar_today_rounded),
      ('Perfil', Icons.person_outline_rounded, Icons.person_rounded),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 28, 10),
        child: _BarSurface(
          glass: glass,
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: Semantics(
                    selected: selectedIndex == index,
                    button: true,
                    child: InkWell(
                      onTap: () => onSelected(index),
                      borderRadius: BorderRadius.circular(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 64),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              selectedIndex == index
                                  ? destinations[index].$3
                                  : destinations[index].$2,
                              color: selectedIndex == index
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              destinations[index].$1,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: selectedIndex == index
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                    fontWeight: selectedIndex == index
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarSurface extends StatelessWidget {
  const _BarSurface({required this.glass, required this.child});

  final bool glass;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(34);
    final decoration = BoxDecoration(
      color: glass
          ? Colors.white.withValues(alpha: 0.42)
          : scheme.surface.withValues(alpha: 0.94),
      borderRadius: radius,
      border: Border.all(
        color: glass
            ? Colors.white.withValues(alpha: 0.7)
            : scheme.outlineVariant,
        width: glass ? 1 : 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: glass ? 0.1 : 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: decoration,
      child: child,
    );
    if (!glass) return content;
    // The blur is clipped to the pill; the shadow stays outside the clip.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: decoration.boxShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: decoration.copyWith(boxShadow: const []),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Picks the bar for the platform: native Liquid Glass on iOS 26+, an
/// approximated glass on older iOS and the regular floating bar elsewhere.
class PatientNavigationBar extends StatelessWidget {
  const PatientNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (_iosMajorVersion >= 26) {
      return NativePatientNavigation(
        selectedIndex: selectedIndex,
        onSelected: onSelected,
      );
    }
    return FloatingPatientNavigation(
      selectedIndex: selectedIndex,
      onSelected: onSelected,
      glass: _iosMajorVersion > 0,
    );
  }
}

/// Major iOS version, or 0 when not running on iOS.
final int _iosMajorVersion = () {
  if (kIsWeb || !Platform.isIOS) return 0;
  final match = RegExp(r'(\d+)').firstMatch(Platform.operatingSystemVersion);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}();

/// UIKit tab bar hosted as a platform view (Liquid Glass on iOS 26).
class NativePatientNavigation extends StatefulWidget {
  const NativePatientNavigation({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<NativePatientNavigation> createState() =>
      _NativePatientNavigationState();
}

class _NativePatientNavigationState extends State<NativePatientNavigation> {
  MethodChannel? _channel;

  @override
  void didUpdateWidget(NativePatientNavigation old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _channel?.invokeMethod<void>('select', widget.selectedIndex);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 4),
      child: SizedBox(
        height: 72,
        child: UiKitView(
          viewType: 'prato_em_dia/native_tab_bar',
          creationParamsCodec: const StandardMessageCodec(),
          creationParams: {
            'selected': widget.selectedIndex,
            'tint': Theme.of(context).colorScheme.primary.toARGB32(),
            'items': const [
              {'title': 'Início', 'symbol': 'circle.circle'},
              {'title': 'Plano', 'symbol': 'calendar'},
              {'title': 'Perfil', 'symbol': 'person'},
            ],
          },
          onPlatformViewCreated: (id) {
            _channel = MethodChannel('prato_em_dia/native_tab_bar/$id')
              ..setMethodCallHandler((call) async {
                if (call.method == 'selected') {
                  widget.onSelected(call.arguments as int);
                }
              });
          },
        ),
      ),
    ),
  );
}
