import 'dart:async';

import 'package:flutter/foundation.dart';

/// Eventos da camada de rede que a interface precisa tratar: o app raiz
/// escuta e mostra a tela correspondente.
class ApiEvents {
  /// Verdadeiro depois de um `426 CLIENT_OUTDATED`. Não volta a falso: a
  /// tela de atualização é bloqueante.
  final ValueNotifier<bool> clientOutdated = ValueNotifier(false);

  final StreamController<void> _sessionExpired = StreamController.broadcast();

  /// Emite quando o refresh falha: a sessão acabou e o app volta ao login.
  Stream<void> get sessionExpired => _sessionExpired.stream;

  /// Chamado pela interface: mostra a tela de aceite e devolve `true` quando
  /// o paciente aceitou. Sem tratador, o `403 CONSENT_REQUIRED` segue como
  /// erro comum.
  Future<bool> Function()? consentHandler;

  Future<bool>? _consentInFlight;

  /// Quantos aceites já foram dados nesta execução. Uma requisição enviada
  /// antes de um aceite e bloqueada depois dele só precisa ser repetida.
  int consentGeneration = 0;

  void notifyClientOutdated() => clientOutdated.value = true;

  void notifySessionExpired() {
    if (!_sessionExpired.isClosed) _sessionExpired.add(null);
  }

  /// Pede o aceite uma única vez, mesmo que várias requisições recebam
  /// `CONSENT_REQUIRED` ao mesmo tempo.
  Future<bool> requestConsent() {
    final handler = consentHandler;
    if (handler == null) return Future.value(false);
    return _consentInFlight ??= handler()
        .then((accepted) {
          if (accepted) consentGeneration++;
          return accepted;
        })
        .whenComplete(() => _consentInFlight = null);
  }

  void dispose() {
    clientOutdated.dispose();
    _sessionExpired.close();
  }
}
