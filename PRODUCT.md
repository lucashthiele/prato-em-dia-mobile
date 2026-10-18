# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Pacientes vinculados a nutricionistas. O nutricionista cria o acesso do paciente por meio do portal web e acompanha a execução do plano alimentar; o paciente usa o aplicativo móvel no cotidiano.

## Product Purpose

Prato em Dia transforma uma prescrição alimentar publicada pelo nutricionista em um plano semanal que o paciente consegue executar. O sucesso do produto é reduzir a distância entre a prescrição e a alimentação realizada no dia a dia.

## Positioning

Em vez de partir do registro retrospectivo de “o que comi”, o produto entrega um plano alimentar semanal, gerado e atualizado a partir da prescrição do nutricionista, para orientar a execução antes das refeições.

## Operating Context

O nutricionista trabalha no portal web: cadastra o paciente, publica a prescrição e gera seu acesso. No aplicativo Flutter, o paciente consulta a prescrição vigente, organiza a semana, usa somente substituições autorizadas, acompanha compras quando disponíveis e registra a execução.

## Capabilities and Constraints

- A prescrição publicada é somente leitura; mudanças criam uma nova versão no portal.
- Planos semanais preservam a versão da prescrição que lhes deu origem.
- Prescrito, planejado e realizado são estados distintos.
- Substituições são limitadas às alternativas autorizadas pelo nutricionista.
- A lista de compras é calculada pelo backend.
- O escopo atual é um MVP. Recursos como compras, histórico dedicado e outras evoluções podem ser incluídos posteriormente conforme os contratos do backend estejam disponíveis.

## Brand Commitments

Nome do produto: Prato em Dia. A experiência deve atender pacientes de nutricionistas sem assumir que eles são clientes pagantes diretos.

## Evidence on Hand

- Documentação de produto e escopo: `docs/produto.md`.
- Diretrizes e estado do aplicativo móvel: `docs/mobile.md`.
- Roadmap do MVP: `docs/roadmap.md`.
- Ativo de marca disponível: `assets/images/prato_em_dia_logo.png`.
- Não há estudos de caso, depoimentos, métricas de validação ou promessas comerciais aprovadas para uso como prova.

## Product Principles

1. Planejar antes de registrar: o plano semanal orienta decisões cotidianas.
2. Preservar a autoria clínica: o paciente consulta e executa uma prescrição publicada, sem alterá-la.
3. Tornar a adesão viável: organização, substituições autorizadas e recuperação após desvios devem reduzir atrito.
4. Distinguir o planejado do realizado para que o acompanhamento seja confiável.
5. Evoluir o MVP sem fingir que recursos ou integrações de roadmap já existem.

## Accessibility & Inclusion

Atender aos fundamentos de acessibilidade móvel: textos com contraste adequado, estados que não dependem apenas de cor, alvos de toque de pelo menos 48 dp e suporte a configurações de fonte e aparência do sistema. A privacidade e o tratamento de dados devem seguir os princípios aplicáveis da LGPD; requisitos específicos serão aprofundados nas próximas etapas do MVP.
