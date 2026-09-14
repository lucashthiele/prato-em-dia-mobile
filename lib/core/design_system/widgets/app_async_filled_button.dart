import 'package:flutter/material.dart';

class AppAsyncFilledButton extends StatelessWidget {
  const AppAsyncFilledButton({
    required this.label,
    required this.loadingLabel,
    required this.isLoading,
    required this.onPressed,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String loadingLabel;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isLoading ? loadingLabel : null,
      liveRegion: isLoading,
      excludeSemantics: isLoading,
      button: isLoading ? true : null,
      enabled: isLoading ? false : null,
      child: FilledButton(
        onPressed: enabled && !isLoading ? onPressed : null,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: isLoading
              ? const SizedBox.square(
                  key: ValueKey('loading'),
                  dimension: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(label, key: const ValueKey('label')),
        ),
      ),
    );
  }
}
