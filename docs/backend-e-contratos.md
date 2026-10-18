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
- Execuções de refeição mutáveis e versionadas (`meal-executions`), com resumo
  nutricional diário. Substituem os antigos eventos imutáveis de conclusão.

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
- `GET /planned-meals/{plannedMealId}/food-log`: itens da refeição e modo
  autoritativo (`RESTRICTED`, `SUBSTITUTIONS_ONLY` ou `FREE`);
- `GET /patients/me/meal-executions?date=`, `POST /patients/me/meal-executions`
  e `PUT /patients/me/meal-executions/{id}`;
- `GET /patients/me/daily-nutrition-summary?date=`;
- resumo de realização para o nutricionista.

As execuções são mutáveis. O `POST` cria e exige `Idempotency-Key`; o `PUT`
substitui a execução inteira e exige `If-Match` com a versão atual, além de
`Idempotency-Key`. O corpo traz `date`, `plannedMealId`, `time` (`HH:mm`), `mealType` e `items`, e cada item
traz `foodId`, `portionId`, `unit`, `quantity`, `multiplier`, `plannedItemId` e,
no modo de substituições, `allowedSubstitutionId`. Uma execução com `items`
vazio representa refeição não realizada.

Os endpoints `completion-events` (`POST`/`GET /planned-meals/{id}/completion-events`
e `GET /patients/me/completion-events`) foram removidos do backend. O app não
os usa mais.

Compras não possui endpoint atual. Remoção, restauração e realocação de
execução não são usadas pelo app e não estão confirmadas; verificar no OpenAPI
gerado pelo backend antes de integrar. Confirmar payloads e status no OpenAPI
antes de alterar a integração.

## Regras de integração

- IDs públicos são UUIDs; datas/timestamps devem preservar fuso/offset quando
  aplicável e semanas usam data civil/ISO 8601.
- O backend valida vínculo, autoria, papel, versão e substituições autorizadas.
- Mutações de publicação e recálculo devem ser transacionais.
- `409` representa conflito de estado/versão; a UI deve recarregar o recurso.
- Criação e substituição de execuções exigem chave de idempotência por intenção;
  repetir a mesma chave e payload devolve a execução já gravada. A substituição
  usa controle otimista: `If-Match` com a versão lida, e `409` se ela mudou.
