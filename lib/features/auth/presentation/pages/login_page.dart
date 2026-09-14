import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/widgets/app_async_filled_button.dart';
import '../../../../core/design_system/widgets/app_brand_mark.dart';
import '../../../../core/design_system/widgets/app_error_banner.dart';
import '../../domain/auth_session.dart';
import '../cubit/login_cubit.dart';
import '../cubit/login_state.dart';
import '../widgets/auth_page_shell.dart';
import '../widgets/auth_password_field.dart';

typedef LoginAuthenticatedCallback = void Function(
  AuthSession session,
  String currentPassword,
);

class LoginPage extends StatefulWidget {
  const LoginPage({required this.onAuthenticated, super.key});

  final LoginAuthenticatedCallback onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    context.read<LoginCubit>().submit(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageShell(
      widePanel: const _WelcomePanel(),
      content: _buildLoginContent(context),
    );
  }

  Widget _buildLoginContent(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocConsumer<LoginCubit, LoginState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == LoginStatus.success,
      listener: (context, state) {
        final session = context.read<LoginCubit>().takeSession();
        if (session != null) {
          widget.onAuthenticated(session, _passwordController.text);
        }
      },
      builder: (context, state) {
        return AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppBrandMark(),
                const SizedBox(height: 48),
                Text(
                  'Que bom ter você aqui',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Entre para acompanhar sua rotina alimentar e o plano preparado para você.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                if (state.errorMessage != null) ...[
                  AppErrorBanner(message: state.errorMessage!),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  controller: _emailController,
                  enabled: !state.isSubmitting,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    hintText: 'voce@exemplo.com',
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                  ),
                  onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Informe o seu e-mail.';
                    final isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(email);
                    if (!isValid) return 'Informe um e-mail válido.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  enabled: !state.isSubmitting,
                  labelText: 'Senha',
                  prefixIcon: Icons.lock_outline_rounded,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Informe a sua senha.';
                    }
                    return null;
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () => _showAccessHelp(context),
                    child: const Text('Precisa de ajuda para entrar?'),
                  ),
                ),
                const SizedBox(height: 8),
                AppAsyncFilledButton(
                  label: 'Entrar',
                  loadingLabel: 'Entrando, aguarde',
                  isLoading: state.isSubmitting,
                  onPressed: _submit,
                ),
                const SizedBox(height: 24),
                Text(
                  'Seu acesso é criado pelo seu nutricionista.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAccessHelp(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.support_agent_rounded),
        title: const Text('Ajuda com o acesso'),
        content: const Text(
          'Peça ao seu nutricionista para reenviar as orientações de acesso ou gerar uma nova senha inicial.',
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.eco_rounded, color: scheme.onPrimary, size: 40),
          ),
          const SizedBox(height: 32),
          Text(
            'Seu plano alimentar,\nmais simples no dia a dia.',
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 20),
          Text(
            'Organize a semana, acompanhe suas refeições e mantenha as orientações do seu nutricionista sempre por perto.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          const _Benefit(
            icon: Icons.calendar_today_rounded,
            label: 'Rotina semanal organizada',
          ),
          const SizedBox(height: 16),
          const _Benefit(
            icon: Icons.restaurant_menu_rounded,
            label: 'Plano sempre à mão',
          ),
          const SizedBox(height: 16),
          const _Benefit(
            icon: Icons.verified_user_outlined,
            label: 'Acesso pessoal e protegido',
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: scheme.onSecondaryContainer, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }
}
