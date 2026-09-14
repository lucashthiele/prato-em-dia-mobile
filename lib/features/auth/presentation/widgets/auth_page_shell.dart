import 'package:flutter/material.dart';

import '../../../../core/design_system/widgets/app_gradient_background.dart';

class AuthPageShell extends StatelessWidget {
  const AuthPageShell({
    required this.content,
    required this.widePanel,
    super.key,
  });

  final Widget content;
  final Widget widePanel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppGradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 768;
              final minContentHeight = constraints.maxHeight > 48
                  ? constraints.maxHeight - 48
                  : 0.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 48 : 24,
                  vertical: 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 1120,
                      minHeight: minContentHeight,
                    ),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: widePanel),
                              const SizedBox(width: 80),
                              SizedBox(width: 420, child: content),
                            ],
                          )
                        : Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: content,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
