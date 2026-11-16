import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/widgets/app_async_filled_button.dart';
import '../../../../core/design_system/widgets/app_error_banner.dart';
import '../../../../core/design_system/widgets/app_gradient_background.dart';
import '../consent_texts.dart';
import '../cubit/consent_cubit.dart';

/// Tela única com os dois documentos e o botão "Aceitar". Fornecer um
/// [ConsentCubit] acima; [onAccepted] segue o fluxo (ou repete a requisição
/// bloqueada) depois que os dois aceites foram gravados.
class ConsentPage extends StatelessWidget {
  const ConsentPage({required this.onAccepted, this.onLogout, super.key});

  final VoidCallback onAccepted;

  /// Opcional: "Sair da conta" para quem não quer aceitar.
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocConsumer<ConsentCubit, ConsentState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == ConsentStatusKind.accepted,
      listener: (context, state) => onAccepted(),
      builder: (context, state) => Scaffold(
        body: AppGradientBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        children: [
                          Text(
                            'Antes de continuar',
                            style: theme.textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Leia os termos de uso e a política de privacidade e aceite para usar o app.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _Document(
                            title: ConsentTexts.termsTitle,
                            paragraphs: ConsentTexts.termsParagraphs,
                          ),
                          const SizedBox(height: 24),
                          _Document(
                            title: ConsentTexts.privacyTitle,
                            paragraphs: ConsentTexts.privacyParagraphs,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (state.errorMessage != null) ...[
                            AppErrorBanner(message: state.errorMessage!),
                            const SizedBox(height: 12),
                          ],
                          AppAsyncFilledButton(
                            label: 'Aceitar',
                            loadingLabel: 'Registrando o aceite, aguarde',
                            isLoading: state.isAccepting,
                            onPressed: () =>
                                context.read<ConsentCubit>().accept(),
                          ),
                          if (onLogout != null)
                            TextButton(
                              onPressed: state.isAccepting ? null : onLogout,
                              child: const Text('Sair da conta'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Document extends StatelessWidget {
  const _Document({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: 8),
        for (final paragraph in paragraphs) ...[
          Text(paragraph, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
