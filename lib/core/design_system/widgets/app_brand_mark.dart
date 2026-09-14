import 'package:flutter/material.dart';

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'Prato em Dia',
      container: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                Icons.eco_rounded,
                color: scheme.onPrimaryContainer,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Prato em Dia',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
