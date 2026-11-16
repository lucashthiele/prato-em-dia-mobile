import 'package:flutter_test/flutter_test.dart';
import 'package:prato_em_dia_mobile/core/network/client_version.dart';

void main() {
  test('formats platform/version+build as the server contract', () {
    expect(
      ClientVersion.format(platform: 'android', version: '2.0.1', build: '45'),
      'android/2.0.1+45',
    );
    expect(
      ClientVersion.format(platform: 'ios', version: '2.0.1'),
      'ios/2.0.1',
    );
    expect(
      ClientVersion.format(platform: 'ios', version: '2.0.1', build: ''),
      'ios/2.0.1',
    );
  });
}
