import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app/theme/app_theme.dart';
import 'core/app_outdated/app_outdated_page.dart';
import 'core/design_system/widgets/app_gradient_background.dart';
import 'core/network/api_client.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/domain/auth_session.dart';
import 'features/auth/presentation/cubit/change_password_cubit.dart';
import 'features/auth/presentation/cubit/login_cubit.dart';
import 'features/auth/presentation/pages/change_password_page.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/consent/data/consent_api.dart';
import 'features/consent/data/consent_repository_impl.dart';
import 'features/consent/domain/consent.dart';
import 'features/consent/presentation/cubit/consent_cubit.dart';
import 'features/consent/presentation/pages/consent_page.dart';
import 'features/home/presentation/pages/patient_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final client = await ApiClient.create();
  runApp(MainApp(apiClient: client));
}

class MainApp extends StatefulWidget {
  const MainApp({required this.apiClient, super.key});

  /// Cliente HTTP compartilhado: cookies de sessão, versão do cliente, refresh
  /// e aceite de termos. Toda feature o recebe daqui.
  final ApiClient apiClient;

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  AuthSession? _session;
  bool _isBootstrapping = true;
  Completer<bool>? _consentRequest;
  StreamSubscription<void>? _sessionExpiredSubscription;

  late final AuthRepositoryImpl _authRepository = AuthRepositoryImpl(
    AuthApi(widget.apiClient.dio),
    clearSession: widget.apiClient.clearSession,
  );
  late final ConsentRepositoryImpl _consentRepository = ConsentRepositoryImpl(
    ConsentApi(widget.apiClient.dio),
  );

  @override
  void initState() {
    super.initState();
    final events = widget.apiClient.events;
    events.consentHandler = _showConsent;
    _sessionExpiredSubscription = events.sessionExpired.listen(
      (_) => _onSessionExpired(),
    );
    _restoreSession();
  }

  @override
  void dispose() {
    widget.apiClient.events.consentHandler = null;
    _sessionExpiredSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final session = await _authRepository.restoreSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _isBootstrapping = false;
    });
  }

  void _onSessionExpired() {
    _finishConsent(false);
    if (mounted) setState(() => _session = null);
  }

  /// Fluxo do primeiro acesso: login -> troca de senha -> aceite.
  Future<void> _onAuthenticated(AuthSession session) async {
    if (!session.passwordChangeRequired) await _ensureConsent();
    if (mounted) setState(() => _session = session);
  }

  /// Mostra o aceite quando `GET /me/consents` vem com `upToDate: false`.
  Future<void> _ensureConsent() async {
    try {
      final status = await _consentRepository.status();
      if (!status.upToDate) await widget.apiClient.events.requestConsent();
    } on ConsentFailure {
      // Sem o status, o `403 CONSENT_REQUIRED` da primeira chamada cobre.
    }
  }

  Future<bool> _showConsent() {
    final request = _consentRequest ??= Completer<bool>();
    if (mounted) setState(() {});
    return request.future;
  }

  void _finishConsent(bool accepted) {
    final request = _consentRequest;
    if (request == null) return;
    _consentRequest = null;
    if (!request.isCompleted) request.complete(accepted);
    if (mounted) setState(() {});
  }

  Future<void> _logout() async {
    _finishConsent(false);
    await _authRepository.logout();
    if (mounted) setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prato em Dia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // O app é só em pt-BR: os componentes do Material (seletor de data e de
      // hora, diálogos) seguem o mesmo idioma das telas.
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Telas bloqueantes ficam acima da navegação, para valer em qualquer
      // ponto do app: atualização obrigatória (426) e aceite de termos.
      builder: (context, child) => Stack(
        children: [
          ?child,
          if (_consentRequest != null)
            BlocProvider(
              key: ObjectKey(_consentRequest),
              create: (_) => ConsentCubit(_consentRepository),
              child: ConsentPage(
                onAccepted: () => _finishConsent(true),
                onLogout: _logout,
              ),
            ),
          ValueListenableBuilder<bool>(
            valueListenable: widget.apiClient.events.clientOutdated,
            builder: (context, outdated, _) =>
                outdated ? const AppOutdatedPage() : const SizedBox.shrink(),
          ),
        ],
      ),
      home: _isBootstrapping
          ? const _SessionBootstrapPage()
          : _session == null
          ? BlocProvider(
              create: (_) => LoginCubit(_authRepository),
              child: LoginPage(onAuthenticated: _onAuthenticated),
            )
          : _session!.passwordChangeRequired
          ? BlocProvider(
              create: (_) => ChangePasswordCubit(_authRepository),
              child: ChangePasswordPage(
                onPasswordChanged: _onAuthenticated,
                onLogout: _logout,
              ),
            )
          : PatientShell(dio: widget.apiClient.dio, onLogout: _logout),
    );
  }
}

class _SessionBootstrapPage extends StatelessWidget {
  const _SessionBootstrapPage();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: 'Verificando sua sessão',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.eco_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Prato em Dia',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
