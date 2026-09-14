import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app/theme/app_theme.dart';
import 'core/config/app_environment.dart';
import 'core/design_system/widgets/app_gradient_background.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository_impl.dart';
import 'features/auth/data/auth_token_store.dart';
import 'features/auth/domain/auth_session.dart';
import 'features/auth/presentation/cubit/change_password_cubit.dart';
import 'features/auth/presentation/cubit/login_cubit.dart';
import 'features/auth/presentation/pages/change_password_page.dart';
import 'features/auth/presentation/pages/login_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  AuthSession? _session;
  String? _currentPasswordForMandatoryChange;
  bool _isBootstrapping = true;

  late final AuthRepositoryImpl _authRepository = AuthRepositoryImpl(
    AuthApi(
      Dio(
        BaseOptions(
          baseUrl: AppEnvironment.apiBaseUrl,
          connectTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 12),
          headers: const {'Accept': 'application/json'},
        ),
      ),
    ),
    SecureAuthTokenStore(const FlutterSecureStorage()),
  );

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    var session = await _authRepository.restoreSession();
    if (session?.passwordChangeRequired ?? false) {
      await _authRepository.logout();
      session = null;
    }
    if (!mounted) return;
    setState(() {
      _session = session;
      _isBootstrapping = false;
    });
  }

  Future<void> _logout() async {
    _currentPasswordForMandatoryChange = null;
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
      home: _isBootstrapping
          ? const _SessionBootstrapPage()
          : _session == null
          ? BlocProvider(
              create: (_) => LoginCubit(_authRepository),
              child: LoginPage(
                onAuthenticated: (session, currentPassword) {
                  setState(() {
                    _session = session;
                    _currentPasswordForMandatoryChange =
                        session.passwordChangeRequired ? currentPassword : null;
                  });
                },
              ),
            )
          : _session!.passwordChangeRequired &&
                _currentPasswordForMandatoryChange != null
          ? BlocProvider(
              create: (_) => ChangePasswordCubit(
                _authRepository,
                _currentPasswordForMandatoryChange!,
              ),
              child: ChangePasswordPage(
                onPasswordChanged: (session) {
                  setState(() {
                    _session = session;
                    _currentPasswordForMandatoryChange = null;
                  });
                },
                onLogout: _logout,
              ),
            )
          : _AuthenticatedPlaceholder(session: _session!, onLogout: _logout),
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

class _AuthenticatedPlaceholder extends StatefulWidget {
  const _AuthenticatedPlaceholder({
    required this.session,
    required this.onLogout,
  });

  final AuthSession session;
  final Future<void> Function() onLogout;

  @override
  State<_AuthenticatedPlaceholder> createState() =>
      _AuthenticatedPlaceholderState();
}

class _AuthenticatedPlaceholderState extends State<_AuthenticatedPlaceholder> {
  bool _isLoggingOut = false;

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prato em Dia')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Acesso realizado com sucesso',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'A sessão foi iniciada e está pronta para carregar o seu plano.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.tonalIcon(
                  onPressed: _isLoggingOut ? null : _logout,
                  icon: _isLoggingOut
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(_isLoggingOut ? 'Saindo...' : 'Sair'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
