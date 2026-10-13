# Dependências de backend para o redesign

Estas capacidades não estão disponíveis como contratos no app/backend
documentados atualmente. Até sua implementação, o mobile pode usar adaptadores
simulados isolados atrás das mesmas interfaces dos repositórios remotos.

| Capacidade pendente | Contrato necessário | Observações |
| --- | --- | --- |
| Busca de catálogo por termo | `q`, cursor/página e tamanho; resultados e metadados de continuação | Não filtrar apenas as páginas já carregadas no aparelho. |
| Resumo nutricional diário | Data/plano, metas prescritas, totais realizados e unidades por nutriente | Distinguir prescrito, planejado e realizado; informar a origem dos cálculos. |
| Períodos disponíveis | Intervalos de datas com plano/prescrição consultável | Deve suportar navegação pelo calendário sem inferir períodos no cliente. |
| CRUD de execuções | Criar, consultar, atualizar e remover execução/refeição, com campos editáveis e regras de modo | O contrato atual documentado é de eventos append-only de conclusão; edição não deve ser simulada como se alterasse esses eventos. |
| Realocação de execução | Mover uma execução entre datas/refeições do plano vigente, com validação de vínculo e conflitos | Definir atomicidade e resposta para destino inválido ou concorrente. |
| Restauração de execução | Restaurar persistidamente uma execução removida durante janela de desfazer | Deve definir token/identificador de restauração, prazo e idempotência. |

## Regra de substituição dos adaptadores

Os adaptadores simulados devem ficar restritos aos contratos acima. Eles não
alteram as regras de prescrição, modos `RESTRICTED`, `SUBSTITUTIONS_ONLY` e
`FREE`, nem autorizam substituições novas. Ao integrar a API, cobrir erros de
autorização, recurso ausente, conflito (`409`) e repetição idempotente segundo
o contrato publicado.
