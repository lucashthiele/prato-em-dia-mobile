# Modelo de dados

## Implementado nas migrations até V013

| Área | Tabelas/agregados principais |
| --- | --- |
| Identidade | `user_account`, `refresh_token` |
| Perfis e vínculo | `nutritionist_profile`, `patient_profile`, `nutritionist_patient_relationship` |
| Catálogo | `food`, `food_portion`, `food_portion_nutrient`, `catalog_import_run` |
| Prescrição | `prescription`, `prescription_version`, `prescribed_meal`, `prescribed_meal_item`, `allowed_substitution` |
| Planejamento | `weekly_plan`, `planned_meal`, `planned_meal_item`, `weekly_planning_preference` |
| Realização | execução de refeição mutável e versionada (substitui `meal_completion_event`; nomes das tabelas a confirmar nas migrations) |

Papéis: `PATIENT`, `NUTRITIONIST`, `ADMIN`. A conta possui estado ativo/inativo.
Um paciente pode ter no máximo um vínculo ativo. Uma prescrição possui versões;
uma versão publicada é imutável e há somente uma publicada por prescrição. As
substituições pertencem ao item prescrito e são a lista fechada de trocas válidas.

O catálogo suporta origem (admin, importado, nutricionista ou paciente), porções
e nutrientes por porção. Importações são auditadas por `catalog_import_run`.

## Planejado para migrations futuras

`shopping_list_item`, `subscription` e `audit_event`.

- O plano semanal guarda a versão publicada de origem.
- A lista de compras é projeção recalculável, não fonte de verdade.
- Execuções de refeição são mutáveis e versionadas (controle otimista por
  `version`); correções editam a execução. Trilha de auditoria fica para
  `audit_event`.
- Assinatura é apenas estado comercial simulado no MVP.

## Convenções

UUID como chave, UTC em `TIMESTAMPTZ`, `snake_case`, FKs e índices compatíveis
com consultas de negócio. Agregados mutáveis usam `created_at`, `updated_at` e
controle de versão. Não editar migrations já aplicadas: qualquer correção entra
em uma migration nova. A configuração recomendada é Hibernate com
`ddl-auto=validate`.
