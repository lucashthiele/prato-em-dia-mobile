import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/core/formatting/decimal.dart';

void main() {
  test('formats with a comma and trims zeros', () {
    expect(formatDecimal(1.5), '1,5');
    expect(formatDecimal(2), '2');
    expect(formatDecimal('12.50'), '12,5');
    expect(formatDecimal(3.456), '3,46');
    expect(formatDecimal(3.456, maxDecimals: 1), '3,5');
    expect(formatDecimal(100), '100');
    expect(formatDecimal('abc'), 'abc');
  });

  test('parses comma or dot', () {
    expect(parseDecimal('1,5'), 1.5);
    expect(parseDecimal('1.5'), 1.5);
    expect(parseDecimal(' 2 '), 2);
    expect(parseDecimal(''), isNull);
    expect(parseDecimal('x'), isNull);
  });

  test('input formatter shows a single comma', () {
    const formatter = DecimalInputFormatter();
    TextEditingValue apply(String old, String next) =>
        formatter.formatEditUpdate(
          TextEditingValue(text: old),
          TextEditingValue(text: next),
        );
    expect(apply('1', '1.').text, '1,');
    expect(apply('1,', '1,5').text, '1,5');
    expect(apply('1,5', '1,5,').text, '1,5');
    expect(apply('1', '1a').text, '1');
    expect(apply('1,123', '1,1234').text, '1,123');
  });
}
