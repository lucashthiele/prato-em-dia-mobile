import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

/// Valor do cabeçalho `X-Client-Version`: `<plataforma>/<versão>`, como em
/// `android/0.1.0+1` (`server/docs/contrato-versao-cliente.md`).
abstract final class ClientVersion {
  static const header = 'X-Client-Version';

  static String format({
    required String platform,
    required String version,
    String? build,
  }) => '$platform/$version${build == null || build.isEmpty ? '' : '+$build'}';

  /// Plataforma e versão do `pubspec.yaml` do app em execução.
  static Future<String> current() async {
    final info = await PackageInfo.fromPlatform();
    return format(
      platform: Platform.isIOS ? 'ios' : 'android',
      version: info.version,
      build: info.buildNumber,
    );
  }
}
