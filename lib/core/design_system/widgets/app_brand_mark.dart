import 'package:flutter/material.dart';

class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Prato em Dia',
      container: true,
      excludeSemantics: true,
      child: ExcludeSemantics(
        child: Image.asset(
          'assets/images/prato_em_dia_logo.png',
          width: 136,
          height: 122,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
