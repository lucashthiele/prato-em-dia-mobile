# Prato em Dia — aplicativo do paciente

Aplicativo Flutter do paciente para o Prato em Dia, uma plataforma B2B2C que
transforma a prescrição publicada por um nutricionista em organização semanal e
execução cotidiana. O nutricionista trabalha no portal web; este projeto é a
experiência mobile do paciente.

## Estado atual

O aplicativo já cobre os fluxos principais do paciente:

- **Autenticação:** login por e-mail e senha, armazenamento seguro do refresh
  token, restauração, validação e renovação serializada da sessão, troca
  obrigatória da senha inicial e logout.
- **Hoje:** plano do dia, resumo nutricional diário e registro de conclusão das
  refeições (execuções), incluindo refeições planejadas sem horário.
- **Semana:** geração, revisão e confirmação do plano semanal, com preferência
  de planejamento.
- **Registro alimentar:** registro do que foi realmente consumido em cada
  refeição planejada, com porções e macros.
- **Catálogo de alimentos:** navegação, busca e detalhes nutricionais dos
  alimentos.
- **Perfil:** dados do paciente e vínculo com o nutricionista.
- **Navegação:** barra flutuante entre as áreas principais do paciente.

O aplicativo usa `dio` para a API REST, `flutter_bloc` (Cubits) para o estado e
`flutter_secure_storage` para credenciais persistentes. Substituições
autorizadas, lista de compras e acompanhamento profissional continuam
planejados; veja o [roadmap](docs/roadmap.md).

## Contexto de produto

O ciclo central do MVP é:

```text
prescrição publicada → planejamento semanal → substituição autorizada
→ lista de compras → registro de execução → acompanhamento profissional
```

Regras que o app deve preservar:

- uma prescrição publicada é somente leitura e imutável;
- o plano semanal mantém a versão da prescrição que o originou;
- substituições são limitadas às opções autorizadas pelo nutricionista;
- prescrito, planejado e realizado são estados distintos;
- compras são calculadas pelo backend, não pelo aplicativo.

Consulte a [base de conhecimento local](docs/README.md) para escopo,
arquitetura, contratos, dados e roadmap. Ela é a síntese dos documentos de
produto e arquitetura do projeto.

## Pré-requisitos

- Flutter compatível com Dart `^3.13.3`;
- backend do Prato em Dia em execução e acessível pelo dispositivo/emulador.

## Executar localmente

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://<host-do-backend>:8080
```

Quando `API_BASE_URL` não é informado, o app usa `http://localhost:8080`. Em
um emulador ou dispositivo físico, use um host que seja alcançável por ele —
`localhost` normalmente aponta para o próprio dispositivo.

## Qualidade

```bash
flutter analyze
flutter test
```

## Estrutura

```text
lib/
  app/                         tema do aplicativo
  core/
    config/                    ambiente (API_BASE_URL)
    design_system/             widgets compartilhados
    formatting/                formatação de decimais
    nutrition/                 modelos de macronutrientes
  features/                    cada feature segue data/domain/presentation
    auth/                      acesso, sessão e troca de senha
    catalog/                   catálogo e detalhes de alimentos
    food_log/                  registro alimentar por refeição
    home/                      tela Hoje e shell de navegação
    planning/                  planejamento semanal
    profile/                   perfil e vínculo com o nutricionista
```

## API usada atualmente

Todas as rotas usam o prefixo `/api/v1`:

| Área | Endpoints |
| --- | --- |
| Autenticação | `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout` |
| Conta | `GET /me`, `PATCH /me/password` |
| Hoje | `GET /patients/me/daily-nutrition-summary`, `/patients/me/meal-executions` |
| Semana | `/patients/me/weekly-plans`, `/patients/me/weekly-planning-preference`, `/weekly-plans/{id}`, `/weekly-plans/{id}/confirm` |
| Registro alimentar | `/planned-meals/{id}/food-log` |
| Catálogo | `GET /foods`, `GET /foods/{id}` |
| Perfil | `GET /patients/me/relationship` |

Os detalhes de payload e respostas devem ser validados no contrato OpenAPI do
backend antes de qualquer alteração de integração.
