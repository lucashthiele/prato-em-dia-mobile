# Produto e escopo

## Proposta

Prato em Dia é uma plataforma B2B2C que reduz a distância entre a prescrição de
um nutricionista e sua execução cotidiana. O nutricionista é o cliente pagante
e trabalha no portal web; o paciente usa o app Flutter para consultar a
prescrição publicada, organizar sua semana e registrar a execução.

O fluxo central é:

```text
nutricionista cadastra paciente e publica prescrição
  → paciente consulta a versão vigente
  → organiza a semana
  → aplica somente substituições autorizadas
  → recebe lista de compras recalculada
  → registra o que realizou
  → nutricionista acompanha uma síntese
```

## Invariantes de domínio

- Prescrição publicada é imutável e somente leitura no app. Uma alteração cria
  uma nova versão em rascunho no portal.
- Um plano semanal referencia a versão publicada que o originou; uma nova
  prescrição não reescreve semanas existentes.
- Prescrito, planejado e realizado são conceitos e estados separados.
- Substituição só pode ser uma opção explicitamente autorizada pelo
  nutricionista.
- Lista de compras é uma projeção consolidada do plano, calculada pelo backend;
  o app não replica o cálculo.
- Autorização é aplicada pelo backend por papel **e** vínculo/autoria, não só
  pelo papel do usuário.

## Recorte do MVP

No aplicativo do paciente: acesso provisionado, sessão, visualização da
prescrição, semana, substituições autorizadas, compras, registro de execução,
histórico simples e perfil. O portal web concentra cadastro de pacientes,
autoria/publicação de prescrições e visão básica de acompanhamento. A área
administrativa é mínima: contas, assinatura simulada e métricas simples.

Ficam fora: cobrança real, chat, teleconsulta, prontuário clínico, inventário
doméstico, solver nutricional, IA, código de barras, notificações push,
sincronização offline completa e publicação formal nas lojas.

## Posicionamento e validação

O diferencial não é ser mais um catálogo de receitas ou contador de calorias:
é entregar **planejamento alimentar executável**. A demonstração de valor deve
mostrar uma semana viável, troca controlada, compras e recuperação após um
desvio.

As referências competitivas mais relevantes são Eat This Much e Prospre
(automação nutricional), Samsung Food (despensa/ecossistema), Mealime
(simplicidade), Paprika/Plan to Eat (receitas pessoais) e MacroFactor/
MyFitnessPal (tracking e distribuição). A orientação é competir em profundidade
operacional e localização brasileira, não em volume de conteúdo.

Métricas recomendadas para validação: tempo até uma semana útil, alimentos
aproveitados, diferença entre compra bruta e líquida, sessões de preparo,
aderência, taxa de replanejamento e percepção de facilidade (SUS). O plano
acadêmico estima 400–450 horas e uma vertical funcional em quatro ou cinco
meses.
