# Prato em Dia — aplicativo do paciente

Aplicativo Flutter do paciente para o Prato em Dia, uma plataforma B2B2C que
transforma a prescrição publicada por um nutricionista em organização semanal e
execução cotidiana. O nutricionista trabalha no portal web; este projeto é a
experiência mobile do paciente.

## Estado atual

O primeiro fluxo já implementado cobre:

- login por e-mail e senha;
- armazenamento seguro do refresh token;
- restauração e validação da sessão;
- renovação da sessão;
- troca obrigatória da senha inicial;
- logout.

O aplicativo usa `dio` para a API REST, `flutter_bloc` para o estado da
autenticação e `flutter_secure_storage` para credenciais persistentes. As
funcionalidades de prescrição, semana, substituições, compras e tracking estão
planejadas, mas ainda não existem neste worktree.

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
  core/                        configuração e design system compartilhado
  features/
    auth/                      acesso, sessão e troca de senha
      data/                    chamadas HTTP e armazenamento seguro
      domain/                  contratos e modelos de autenticação
      presentation/            páginas, Cubits e widgets
```

## API usada atualmente

O fluxo de autenticação espera o prefixo `/api/v1` e utiliza:

- `POST /auth/login`
- `POST /auth/refresh`
- `GET /me`
- `PATCH /me/password`
- `POST /auth/logout`

Os detalhes de payload e respostas devem ser validados no contrato OpenAPI do
backend antes de qualquer alteração de integração.
