import 'package:flutter/material.dart';

import '../design_system/widgets/app_gradient_background.dart';

/// Tela bloqueante do `426 CLIENT_OUTDATED` (Q21): só a mensagem pedindo a
/// atualização, sem link, porque não há APK distribuído.
class AppOutdatedPage extends StatelessWidget {
  const AppOutdatedPage({super.key});

  static const title = 'Atualize o aplicativo';
  static const message =
      'Esta versão do Prato em Dia não é mais aceita. Atualize o aplicativo para continuar.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AppGradientBackground(
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.system_update_rounded,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
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
