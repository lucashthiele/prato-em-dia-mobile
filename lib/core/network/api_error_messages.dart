import 'api_failure.dart';

/// Mensagens em pt-BR por código do catálogo de erros do servidor
/// (`server/docs/erros.md`, classes `*ErrorCatalogSection`).
///
/// Ordem de resolução de [ApiErrorMessages.of]: mensagem do contexto
/// (`overrides`), mensagem do catálogo, `message` do servidor, texto por
/// status HTTP e, sem resposta, o texto de erro de rede.
abstract final class ApiErrorMessages {
  static const network =
      'Não foi possível conectar. Verifique sua internet e tente novamente.';
  static const generic = 'Algo deu errado. Tente novamente em instantes.';
  static const serverUnavailable =
      'O serviço está indisponível no momento. Tente novamente em instantes.';

  static const catalog = <String, String>{
    // Sessão e acesso
    'AUTH_INVALID_CREDENTIALS':
        'E-mail ou senha incorretos. Confira os dados e tente novamente.',
    'AUTH_ACCOUNT_INACTIVE':
        'Esta conta está inativa. Fale com o seu nutricionista.',
    'AUTH_REFRESH_TOKEN_INVALID': 'Sua sessão terminou. Entre novamente.',
    'AUTH_REFRESH_TOKEN_EXPIRED': 'Sua sessão expirou. Entre novamente.',
    'AUTHENTICATION_REQUIRED': 'Sua sessão terminou. Entre novamente.',
    'LOGIN_RATE_LIMITED':
        'Muitas tentativas de acesso. Aguarde alguns minutos e tente de novo.',
    'ACCESS_DENIED': 'Você não tem permissão para esta ação.',
    'ORIGIN_NOT_ALLOWED': 'Esta origem não pode fazer esta operação.',
    'PASSWORD_CHANGE_REQUIRED':
        'Crie sua senha pessoal para continuar usando o app.',
    'CONSENT_REQUIRED':
        'Aceite os termos de uso e a política de privacidade para continuar.',
    'CONSENT_VERSION_MISMATCH':
        'Os termos foram atualizados. Leia e aceite novamente.',
    'CLIENT_OUTDATED':
        'Esta versão do app não é mais aceita. Atualize o aplicativo.',
    // Conta e requisição
    'IDENTITY_ACCOUNT_ALREADY_EXISTS': 'Já existe uma conta com este e-mail.',
    'PATIENT_ACCOUNT_CONFLICT':
        'Já existe uma conta de paciente com estes dados.',
    'INITIAL_PASSWORD_NOT_AVAILABLE':
        'A senha inicial não está mais disponível.',
    'USER_ACCOUNT_NOT_FOUND': 'A conta não foi encontrada.',
    'ACCESS_EMAIL_NOT_AVAILABLE': 'Este e-mail não está disponível.',
    'ADMIN_CANNOT_CHANGE_OWN_STATUS':
        'Você não pode alterar o estado da própria conta.',
    'END_RELATIONSHIPS_NOT_APPLICABLE':
        'Não há vínculos para encerrar nesta conta.',
    'AUDIT_INVALID_FILTER': 'Os filtros informados não são válidos.',
    'VALIDATION_ERROR': 'Revise os dados informados e tente novamente.',
    'INVALID_REQUEST_BODY': 'Revise os dados informados e tente novamente.',
    'INVALID_REQUEST_PARAMETER':
        'Revise os dados informados e tente novamente.',
    'ROUTE_NOT_FOUND': 'Este recurso não está disponível nesta versão.',
    'METHOD_NOT_ALLOWED': 'Esta operação não está disponível.',
    'UNSUPPORTED_MEDIA_TYPE': 'Não foi possível enviar os dados.',
    'INTERNAL_ERROR': serverUnavailable,
    // Planejamento
    'WEEKLY_PLAN_NOT_FOUND': 'O plano semanal não foi encontrado.',
    'PLANNING_ACCESS_DENIED': 'Você não tem acesso a este plano.',
    'PLANNING_CONFLICT':
        'O plano mudou e não permite esta alteração. Atualize e tente de novo.',
    'WEEKLY_PLAN_GENERATION_CONFLICT':
        'O plano está sendo gerado agora. Atualize em instantes.',
    'INVALID_PLANNING': 'A alteração não é permitida pela sua prescrição. Revise e tente de novo.',
    // Perfil
    'PROFILE_NOT_FOUND': 'Seu perfil não foi encontrado.',
    'PROFILE_NOT_AVAILABLE': 'O perfil não está disponível para esta conta.',
    'PROFILE_FIELDS_NOT_ALLOWED': 'Algum dos campos não pode ser alterado.',
    'PROFILE_INVALID_VALUE': 'Revise os dados do perfil e tente novamente.',
    // Registro
    'TRACKING_NOT_FOUND':
        'A refeição ou o registro não está mais disponível. Atualize a tela.',
    'TRACKING_FORBIDDEN': 'Você não tem acesso a este registro.',
    'TRACKING_CONFLICT':
        'O registro mudou. Atualize a tela antes de tentar de novo.',
    'TRACKING_INVALID':
        'Os alimentos informados não são aceitos para esta refeição.',
    'NO_ALLOWED_FOODS': 'Seu plano não prevê alimentos para esta refeição.',
    // Catálogo
    'FOOD_NOT_FOUND': 'O alimento não foi encontrado.',
    'FOOD_ACCESS_DENIED': 'Você não tem acesso a este alimento.',
    'CATALOG_INVALID_VALUE': 'Os dados do alimento não são válidos.',
    // Prescrição e vínculo
    'PRESCRIPTION_NOT_FOUND': 'Você não tem uma prescrição ativa.',
    'PRESCRIPTION_ACCESS_DENIED': 'Você não tem acesso a esta prescrição.',
    'PRESCRIPTION_CONFLICT': 'A prescrição mudou. Atualize e tente de novo.',
    'INVALID_PRESCRIPTION_REFERENCE':
        'A prescrição usa um item que não está disponível.',
    'INVALID_PRESCRIPTION': 'Os dados da prescrição não são válidos.',
    'RELATIONSHIP_NOT_FOUND':
        'O vínculo com o nutricionista não foi encontrado.',
    'RELATIONSHIP_CONFLICT': 'Este vínculo não permite a operação.',
    'RELATIONSHIP_ALREADY_EXISTS': 'O vínculo já existe.',
    'RELATIONSHIP_EMAIL_FAILED':
        'Não foi possível enviar o e-mail agora. Tente novamente em instantes.',
    'RELATIONSHIP_INVALID_VALUE': 'Os dados do vínculo não são válidos.',
    // Lista de compras (fora do MVP, mas o servidor ainda devolve)
    'SHOPPING_LIST_NOT_FOUND': 'O plano não tem lista de compras ativa.',
    'SHOPPING_PLAN_NOT_FOUND':
        'O plano da lista de compras não foi encontrado.',
    'SHOPPING_ACCESS_DENIED': 'Você não tem acesso a esta lista de compras.',
  };

  /// Texto para exibir. [overrides] troca a mensagem de códigos específicos
  /// no contexto da tela (por exemplo, `AUTH_INVALID_CREDENTIALS` na troca de
  /// senha quer dizer "senha atual incorreta").
  static String of(
    ApiFailure failure, {
    Map<String, String> overrides = const {},
    String? fallback,
  }) {
    if (failure.isNetwork) return overrides['NETWORK'] ?? network;
    final code = failure.code;
    if (code != null) {
      final text = overrides[code] ?? catalog[code];
      if (text != null) return text;
    }
    final serverMessage = failure.message;
    if (serverMessage != null) return serverMessage;
    final status = failure.status;
    if (status != null && status >= 500) return serverUnavailable;
    return fallback ?? generic;
  }

  /// Atalho para um erro qualquer capturado em um `catch`.
  static String ofError(
    Object error, {
    Map<String, String> overrides = const {},
    String? fallback,
  }) => of(ApiFailure.from(error), overrides: overrides, fallback: fallback);
}
