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
- Planejamento semanal, preferência de geração automática e confirmação.
- Eventos imutáveis de realização e histórico paginado do paciente.

Rotas importantes já previstas/implementadas incluem `POST /auth/login`,
`POST /auth/refresh`, `POST /auth/logout`, `GET /me`, `PUT /me`,
`PATCH /me/password`, `GET /patients/me/relationship` e
`GET /patients/me/prescriptions/current`. O prefixo é `/api/v1`; erros usam
Problem Details.

## Planejamento e tracking disponíveis

O contrato atual inclui:

- `POST`/`GET /patients/me/weekly-plans`, `GET`/`PATCH /weekly-plans/{planId}`
  e `POST /weekly-plans/{planId}/confirm`;
- `GET`/`PUT /patients/me/weekly-planning-preference`;
- `POST`/`GET /planned-meals/{plannedMealId}/completion-events` e
  `GET /patients/me/completion-events`;
- resumo de realização para o nutricionista.

O `POST` de realização exige `Idempotency-Key`. Compras não possui endpoint
atual. Confirmar payloads e status no OpenAPI gerado pelo backend antes de
alterar a integração.

## Regras de integração

- IDs públicos são UUIDs; datas/timestamps devem preservar fuso/offset quando
  aplicável e semanas usam data civil/ISO 8601.
- O backend valida vínculo, autoria, papel, versão e substituições autorizadas.
- Mutações de publicação e recálculo devem ser transacionais.
- `409` representa conflito de estado/versão; a UI deve recarregar o recurso.
- Eventos de realização exigem chave de idempotência por intenção; repetir a
  mesma chave e payload devolve o evento já criado.
