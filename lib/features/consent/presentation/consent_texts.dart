/// Textos preliminares embutidos no app (Q12). A versão aceita vem do
/// servidor (`placeholder-1`); estes textos não são versão jurídica final.
abstract final class ConsentTexts {
  /// Frase exigida pelo A-02.
  static const nutritionistVisibility =
      'O nutricionista vinculado a você vê as refeições que você planeja e registra no app.';

  static const termsTitle = 'Termos de uso';
  static const termsParagraphs = [
    'O Prato em Dia ajuda você a seguir o plano alimentar preparado pelo seu nutricionista.',
    nutritionistVisibility,
    'Você é responsável por manter sua senha em sigilo e por registrar as refeições com sinceridade.',
    'O app não substitui o acompanhamento do seu nutricionista. Em caso de dúvida sobre sua alimentação, fale com ele.',
    'Esta é uma versão preliminar dos termos, usada na fase de demonstração do projeto.',
  ];

  static const privacyTitle = 'Política de privacidade';
  static const privacyParagraphs = [
    'Guardamos seus dados de cadastro, suas refeições planejadas e seus registros de alimentação para oferecer o plano e permitir o acompanhamento.',
    'Esses dados ficam disponíveis para você e para o nutricionista vinculado à sua conta. Não os compartilhamos com terceiros.',
    'Você pode pedir a correção dos seus dados ao seu nutricionista.',
    'Esta é uma versão preliminar da política, usada na fase de demonstração do projeto.',
  ];
}
