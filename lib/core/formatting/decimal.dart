import 'package:flutter/services.dart';

/// Formats a number the pt-BR way (comma as decimal separator), trimming
/// trailing zeros. Accepts a number or a numeric string such as the API's
/// "12.5"; anything else is returned unchanged.
String formatDecimal(Object? value, {int maxDecimals = 2}) {
  final number = value is num ? value : num.tryParse('$value');
  if (number == null) return '$value';
  var text = number.toStringAsFixed(maxDecimals);
  if (text.contains('.')) {
    text = text
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  if (text == '-0') text = '0';
  return text.replaceFirst('.', ',');
}

/// Parses user input with either "," or "." as the decimal separator.
num? parseDecimal(String text) {
  final value = text.trim();
  if (value.isEmpty) return null;
  return num.tryParse(value.replaceAll(',', '.'));
}

/// Keeps only digits and one decimal separator, always shown as ",".
class DecimalInputFormatter extends TextInputFormatter {
  const DecimalInputFormatter({this.maxDecimals = 3});

  final int maxDecimals;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll('.', ',');
    final match = RegExp(r'^\d*(,\d*)?$').firstMatch(raw);
    if (match == null) return oldValue;
    final decimals = match.group(1);
    if (decimals != null && decimals.length - 1 > maxDecimals) return oldValue;
    return newValue.copyWith(
      text: raw,
      selection: newValue.selection.copyWith(
        baseOffset: newValue.selection.baseOffset.clamp(0, raw.length),
        extentOffset: newValue.selection.extentOffset.clamp(0, raw.length),
      ),
    );
  }
}
