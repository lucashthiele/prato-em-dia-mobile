import 'package:flutter/material.dart';

/// Estado vazio do paciente sem prescrição (Q24, A-01). Sem ação.
class NoPrescriptionEmptyState extends StatelessWidget {
  const NoPrescriptionEmptyState({super.key});

  static const message =
      'Você não tem um plano ativo no momento. '
      'Seu nutricionista publica um novo plano por aqui.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
