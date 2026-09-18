# Backend e contratos

O backend é Spring Boot modular por feature, com abordagem Clean/Hexagonal
pragmática. Em cada feature, `domain` não conhece Spring/JPA/HTTP; `application`
expõe casos de uso e portas; `infrastructure` contém persistência/segurança; e
`presentation` contém controllers e DTOs HTTP. Flyway é a autoridade do schema.

## O que está implementado

- Identidade, perfis, refresh token e autenticação.
- Vínculo nutricionista–paciente, incluindo provisionamento de acesso e envio de
  e-mail. Não há token de convite nem consentimento separado no contrato atual.
- Catálogo alimentar, porções, nutrientes e importação.
- Prescrições versionadas, refeições, itens, substituições permitidas e
  publicação imutável.

Rotas importantes já previstas/implementadas incluem `POST /auth/login`,
`POST /auth/refresh`, `POST /auth/logout`, `GET /me`, `PUT /me`,
`PATCH /me/password`, `GET /patients/me/relationship` e
`GET /patients/me/prescriptions/current`. O prefixo é `/api/v1`; erros usam
Problem Details.

## Próximo incremento — ainda não implementado

Planejamento, compras e tracking são roadmap. As rotas planejadas incluem:

- `POST`/`GET /patients/me/weekly-plans` e `GET`/`PATCH /weekly-plans/{planId}`;
- substituição por refeição e leitura/recalculo de shopping list;
- eventos de conclusão por `plannedMealId` e histórico do paciente;
- resumo semanal para o nutricionista.

Esses endpoints são direção de contrato, não garantia de que o Flutter possa
chamá-los hoje. Confirmar payloads e status no OpenAPI do backend antes da
integração.

## Regras de integração

- IDs públicos são UUIDs; datas/timestamps devem preservar fuso/offset quando
  aplicável e semanas usam data civil/ISO 8601.
- O backend valida vínculo, autoria, papel, versão e substituições autorizadas.
- Mutações de publicação e recálculo devem ser transacionais.
- `409` representa conflito de estado/versão; a UI deve recarregar o recurso.
- Idempotência em comandos sensíveis está planejada, mas ainda não é declarada
  nos endpoints atuais.
