# Dependências de backend para o redesign

O backend migrou de eventos de conclusão imutáveis para execuções mutáveis
(`meal-executions`). O app já consome busca por `q`, resumo diário e criação e
edição de execuções. Faltam os contratos abaixo, ou a confirmação de que
existem. Até lá, o mobile deve manter adaptadores isolados atrás das mesmas
interfaces dos repositórios remotos.

| Capacidade pendente | Contrato necessário | Observações |
| --- | --- | --- |
| Períodos disponíveis | Intervalos de datas com plano/prescrição consultável | Hoje o app infere os períodos a partir de `weekly-plans`. Deve suportar navegação pelo calendário sem inferir períodos no cliente. |
| Remoção de execução | Remover execução/refeição, com regras de modo | Criação (`POST`), consulta (`GET`) e substituição (`PUT` com `If-Match`) já são usadas pelo app. Falta confirmar a remoção. |
| Realocação de execução | Mover uma execução entre datas/refeições do plano vigente, com validação de vínculo e conflitos | Definir atomicidade e resposta para destino inválido ou concorrente. |
| Restauração de execução | Restaurar persistidamente uma execução removida durante janela de desfazer | Deve definir token/identificador de restauração, prazo e idempotência. |

## Já integrado

| Capacidade | Contrato usado pelo app |
| --- | --- |
| Busca de catálogo por termo | `GET /foods?q=` |
| Resumo nutricional diário | `GET /patients/me/daily-nutrition-summary?date=` |
| Execuções mutáveis | `GET`/`POST /patients/me/meal-executions`, `PUT /patients/me/meal-executions/{id}` com `If-Match` e `Idempotency-Key` |

Confirmar a paginação (cursor e tamanho) da busca no OpenAPI.

## Regra de substituição dos adaptadores

Os adaptadores simulados devem ficar restritos aos contratos acima. Eles não
alteram as regras de prescrição, modos `RESTRICTED`, `SUBSTITUTIONS_ONLY` e
`FREE`, nem autorizam substituições novas. Ao integrar a API, cobrir erros de
autorização, recurso ausente, conflito (`409`) e repetição idempotente segundo
o contrato publicado.
