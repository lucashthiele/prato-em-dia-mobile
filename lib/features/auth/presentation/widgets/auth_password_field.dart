import 'package:flutter/material.dart';

class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    required this.controller,
    required this.labelText,
    required this.prefixIcon,
    required this.validator,
    this.focusNode,
    this.enabled = true,
    this.helperText,
    this.textInputAction,
    this.autofillHints = const [AutofillHints.password],
    this.onChanged,
    this.onFieldSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String labelText;
  final String? helperText;
  final IconData prefixIcon;
  final bool enabled;
  final TextInputAction? textInputAction;
  final Iterable<String> autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String> validator;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscureText,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: widget.labelText,
        helperText: widget.helperText,
        prefixIcon: Icon(widget.prefixIcon),
        suffixIcon: IconButton(
          tooltip: _obscureText ? 'Mostrar senha' : 'Ocultar senha',
          onPressed: widget.enabled
              ? () => setState(() => _obscureText = !_obscureText)
              : null,
          icon: Icon(
            _obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator,
    );
  }
}
