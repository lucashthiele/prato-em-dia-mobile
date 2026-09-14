import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/widgets/app_async_filled_button.dart';
import '../../../../core/design_system/widgets/app_brand_mark.dart';
import '../../../../core/design_system/widgets/app_error_banner.dart';
import '../../domain/auth_session.dart';
import '../cubit/change_password_cubit.dart';
import '../cubit/change_password_state.dart';
import '../widgets/auth_page_shell.dart';
import '../widgets/auth_password_field.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({
    required this.onPasswordChanged,
    required this.onLogout,
    super.key,
  });

  final ValueChanged<AuthSession> onPasswordChanged;
  final Future<void> Function() onLogout;

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _confirmationFocusNode = FocusNode();
  bool _isLoggingOut = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmationController.dispose();
    _confirmationFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    context.read<ChangePasswordCubit>().submit(
      newPassword: _newPasswordController.text,
    );
  }

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
    return AuthPageShell(
      widePanel: const _PasswordIntro(),
      content: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == ChangePasswordStatus.success,
      listener: (context, state) {
        final session = context.read<ChangePasswordCubit>().takeSession();
        if (session != null) widget.onPasswordChanged(session);
      },
      builder: (context, state) {
        final isBusy = state.isSubmitting || _isLoggingOut;
        return AutofillGroup(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppBrandMark(),
                const SizedBox(height: 40),
                Text(
                  'Crie sua senha pessoal',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Este é seu primeiro acesso. Troque a senha inicial por uma senha que só você conhece.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (state.errorMessage != null) ...[
                  AppErrorBanner(message: state.errorMessage!),
                  const SizedBox(height: 20),
                ],
                AuthPasswordField(
                  controller: _newPasswordController,
                  enabled: !isBusy,
                  labelText: 'Nova senha',
                  helperText: 'Use entre 12 e 72 caracteres.',
                  prefixIcon: Icons.lock_outline_rounded,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) {
                    if (_confirmationController.text.isNotEmpty) {
                      _formKey.currentState?.validate();
                    }
                  },
                  onFieldSubmitted: (_) =>
                      _confirmationFocusNode.requestFocus(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Crie uma nova senha.';
                    }
                    if (value.length < 12 || value.length > 72) {
                      return 'Use entre 12 e 72 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthPasswordField(
                  controller: _confirmationController,
                  focusNode: _confirmationFocusNode,
                  enabled: !isBusy,
                  labelText: 'Confirme a nova senha',
                  prefixIcon: Icons.lock_reset_rounded,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirme a nova senha.';
                    }
                    if (value != _newPasswordController.text) {
                      return 'As senhas não coincidem.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                AppAsyncFilledButton(
                  label: 'Salvar e continuar',
                  loadingLabel: 'Salvando nova senha, aguarde',
                  isLoading: state.isSubmitting,
                  enabled: !_isLoggingOut,
                  onPressed: _submit,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: isBusy ? null : _logout,
                  icon: _isLoggingOut
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.logout_rounded),
                  label: Text(_isLoggingOut ? 'Saindo...' : 'Sair da conta'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PasswordIntro extends StatelessWidget {
  const _PasswordIntro();

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
            child: Icon(
              Icons.lock_reset_rounded,
              color: scheme.onPrimary,
              size: 40,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Seu acesso,\nmais seguro desde o início.',
            style: theme.textTheme.displaySmall,
          ),
          const SizedBox(height: 20),
          Text(
            'Depois desta etapa, você poderá acessar seu plano alimentar normalmente.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
