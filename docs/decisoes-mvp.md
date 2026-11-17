# Decisões para fechar o MVP do app

Perguntas que precisavam de resposta antes de implementar o que falta no app do
paciente. Elas saem da comparação entre o escopo do MVP (`Marcos do MVP`,
`produto.md`, `Arquitetura do aplicativo Flutter`, `Plano consolidado`), o
backend e o código do app.

Fechadas em 16/11/2026, junto com os pedidos da sessão de fechamento do portal
([pedidos-mvp-final-2026-11-16.md](pedidos-mvp-final-2026-11-16.md), itens
A-01 a A-05) e depois de conferir o servidor no merge `ee2e4f5` (S-01 a S-09).
A entrega final do TCC é em 17/11/2026 e o deploy está fora do escopo, o que
explica os cortes da Q11, Q14, Q21 e Q23.

Estão organizadas em rodadas. Uma pergunta só entra numa rodada quando as
perguntas de que ela depende já foram respondidas. Salvo indicação contrária na
tabela do fim, a resposta é a recomendação (➡️).

Termos de domínio seguem `server/GLOSSARY.md` e `portal-web/GLOSSARY.md`.
Quando uma resposta mudar ou criar um termo, atualizar o glossário junto. As
mudanças de servidor que estas respostas pedem estão em
`server/docs/pedidos-app-mvp-final-2026-11-16.md`.

O que já está decidido e não volta para discussão: as mudanças marcadas como
**Decidido** em [mudancas-de-servidor.md](mudancas-de-servidor.md), o tema
escuro fora do escopo e a publicação em lojas fora do MVP.

---

## Rodada 1 — perguntas sem dependência

### Q1 — "Não realizada" continua no MVP?

O Marco 4 pede registrar a refeição como realizada, não realizada ou realizada
com substituição. Mas o modelo mudou:

- o glossário define **Execução** como o registro "do que o paciente consumiu";
- o **Estado da categoria** só tem Sem registro, Parcial e Registrada (A-05);
- o critério de aceite 4 do plano consolidado diz que nenhuma execução fica sem
  alimento.

Hoje o app grava "não realizada" como uma execução sem itens
(`today_repository_impl.dart`), o que contradiz esse modelo. O servidor ainda
aceita execução sem itens: numa categoria `FREE` ela vira `LOGGED`, e nos modos
restritos vira `PARTIAL`.

Opções:

- **a)** Tirar "não realizada" do MVP. A categoria sem registro fica como Sem
  registro, e a síntese do nutricionista lê isso como não cumprida depois que
  o dia passa.
- **b)** Criar no servidor um conceito próprio (por exemplo, **Refeição
  pulada**), separado da execução, com novo estado da categoria.
- **c)** Manter a execução sem itens e relaxar o critério 4.

➡️ **a)**. Remover o botão do app e atualizar o texto do Marco 4. O servidor
passa a recusar execução sem itens (pedido P-02). O portal confirma que "não
realizada" não existe no MVP (A-05).

### Q2 — Como o paciente entra no registro, e isso vale em dia sem plano?

O plano consolidado exige as quatro categorias em todo dia, inclusive dia sem
plano com prescrição `FREE`, e um botão global "Registrar alimento". O plano de
redesign tirou esse botão. O app hoje só registra a partir de uma refeição
planejada.

Opções:

- **a)** Sem botão global. O Início sempre mostra as quatro categorias vindas
  de `daily-meal-categories`, com ou sem plano, e cada uma abre o registro.
- **b)** Botão global que abre o seletor das quatro categorias, e o Início
  também.

➡️ **a)**. Um caminho só, já suportado pela rota nova, e o critério 1 é
atendido. A exceção é o paciente sem prescrição (Q24).

### Q3 — Onde fica a Lista de compras?

A arquitetura do app põe Compras como aba própria. O redesign tirou Compras da
navegação (fica Início, Semana e Perfil). A lista pertence a um plano semanal.

➡️ **Sai do MVP.** O servidor consolida a lista por alimento prescrito, porção
e unidade, sem decompor em ingredientes (M-07). Para um alimento preparado,
como um strogonoff, a lista diria "strogonoff, 300 g", o que não serve para ir
ao mercado. As rotas do servidor (LUC-30) ficam prontas para depois do MVP. O
LUC-18 sai do MVP.

### Q4 — O paciente pode reorganizar a semana além de trocar itens?

O app não usa o `PATCH /weekly-plans/{planId}`. Esse `PATCH` recebe a versão
e a lista inteira de refeições do plano: data, categoria, nome, ordem e itens
(alimento, porção, quantidade, unidade). Não há campo de substituição: a troca
é feita mudando o alimento do item, e o servidor valida contra o modo e as
substituições autorizadas. Como só pode haver uma refeição ativa por dia e
categoria, mover uma refeição de dia na prática é trocar duas refeições de
lugar. Num plano já confirmado (o servidor confirma automaticamente), a troca
de itens continua permitida e só a mudança de agenda é recusada.

Opções:

- **a)** Só substituição autorizada (LUC-17), sem mover refeições entre dias.
- **b)** Substituição e reorganização (trocar refeições de dia).

➡️ **a)**. Reorganizar não é necessário para a demonstração, e a troca entre
dias exige uma interface de arrastar ou trocar que custa caro.

### Q5 — O paciente pode excluir um plano semanal no app?

O servidor já tem `DELETE /weekly-plans/{planId}` (LUC-37). O app não usa.

➡️ Sim, com confirmação. É barato e evita que um plano gerado errado fique
preso até regenerar. Fica entre as últimas etapas (Q23).

### Q6 — Quais operações de execução entram no MVP?

O servidor já tem remover, desfazer em 5 s e mover execução (`DELETE`,
`restore`, `move`).

➡️ Remover com Desfazer entra. Mover sai do MVP: o paciente pode remover e
registrar de novo.

### Q7 — O histórico ganha tela própria (LUC-24)?

O roadmap aceita cortar o histórico detalhado primeiro. O paciente só lista
execuções por dia (`GET /patients/me/meal-executions?date=`); listar por
período existe só para o nutricionista.

Opções:

- **a)** Sem tela dedicada: navegar dias no calendário do Início, guiado por
  `calendar-periods`, já é o histórico simples.
- **b)** Tela de histórico por período, o que pede rota nova no servidor.

➡️ **a)**. Fechar o LUC-24 como coberto pelo calendário.

### Q8 — Onde fica a tela de prescrição e o que ela mostra (LUC-15)?

A rota é `GET /patients/me/prescriptions/current`. Sem versão vigente, ela
responde `404 PRESCRIPTION_NOT_FOUND`.

➡️ Acesso por um cartão no Perfil, como diz a arquitetura. Mostrar autoria,
versão, data de publicação, modo, refeições com itens e substituições
autorizadas, observações e metas nutricionais. Nenhuma ação de edição. Sem
prescrição, o cartão mostra o estado vazio da Q24.

### Q9 — Encerrar o vínculo pelo paciente entra no MVP?

O escopo do app inclui encerrar o vínculo. O servidor já tem a rota do
paciente (`DELETE /patients/me/relationship`), e com o S-07 encerrar o vínculo
arquiva a prescrição daquele par: o paciente fica sem plano novo.

➡️ Sai do MVP. A ação é destrutiva e não acrescenta nada à demonstração. O
Perfil só mostra o vínculo.

### Q10 — "Recuperação após desvio" (LUC-20) entra no MVP?

O `produto.md` diz que a demonstração deve mostrar recuperação após um desvio,
mas a feature não tem definição.

➡️ Sai do MVP como feature própria. Na demonstração, a recuperação é contada
com o que já existe: regenerar o plano a partir de um dia e registrar
livremente em `FREE`. Atualizar o `produto.md`.

### Q11 — Em que plataforma roda a demonstração?

➡️ Android, com build local em emulador ou aparelho, apontando para o servidor
da demonstração. iOS só no simulador. O APK de staging distribuído sai do MVP,
porque o deploy está fora do escopo.

### Q12 — Quem escreve os termos de uso e a política de privacidade (LUC-65)?

O app precisa da tela de aceite. O servidor só controla as versões
(`CONSENT_TERMS_VERSION` e `CONSENT_PRIVACY_VERSION`, padrão `placeholder-1`) e
não entrega os textos.

➡️ Texto curto próprio, embutido no app, como versão preliminar (a
demonstração usa só contas de teste, Q32 do portal). Os termos de uso incluem a
frase do A-02: "O nutricionista vinculado a você vê as refeições que você
planeja e registra no app." A versão continua `placeholder-1`. Se o comitê de
ética exigir TCLE, ele fica fora do app.

### Q13 — Troca de senha pelo Perfil entra no MVP?

O app só troca a senha no primeiro acesso.

➡️ Sim, entre as últimas etapas (Q23). A rota e a tela já existem; é só dar
acesso pelo Perfil. A tela passa a ter dois modos:

- **Primeiro acesso** (`passwordChangeRequired = true`): pede só a nova senha
  e a confirmação (A-04).
- **Pelo Perfil**: a senha atual continua obrigatória.

### Q14 — Qual o mínimo de testes para entregar?

➡️ `dart format`, `flutter analyze` e os testes passando localmente antes da
entrega. Testes de unidade para sessão e mapeamentos e testes de widget para as
telas novas, na medida do prazo. O CI no GitHub Actions, o build Android no CI
e o teste integrado do ciclo completo saem do MVP.

---

## Rodada 2 — dependem da rodada 1

### Q15 — Se Q1 = a): o que o app mostra numa categoria Sem registro de um dia que já passou?

➡️ Continua **Sem registro**, com a mesma aparência. O app não julga o
paciente; a leitura de "não cumprida" é do portal. Os nomes dos estados são os
do portal (A-05): Registrada, Parcial e Sem registro, com a marca **Com
substituição**.

### Q16 — Se Q2 = a): o que aparece numa categoria bloqueada?

O servidor tem um único `blockedReason`, `NO_ALLOWED_FOODS`, para três casos:

- paciente sem prescrição (tratado na Q24);
- dia sem plano com prescrição `RESTRICTED` ou `SUBSTITUTIONS_ONLY`;
- categoria planejada sem itens nesses modos.

➡️ Nos dois últimos casos, a categoria aparece desabilitada com a frase "Seu
plano não prevê alimentos para esta refeição", sem botão de registro.

### Q17 — Se Q2 = a): data e hora no registro

➡️ A data é a do dia aberto no Início e não muda no registro. A hora começa no
horário atual (ou no `suggestedTime` da prescrição, quando houver) e é
editável. A refeição planejada não tem mais horário (M-04).

### Q18 — Se Q3 = a): a lista é criada sozinha ao abrir?

➡️ Não se aplica: a lista de compras saiu do MVP (Q3).

### Q19 — Se Q4 = a): como é o fluxo de troca na Semana (LUC-17)?

➡️ Na refeição planejada, tocar no item abre só as substituições autorizadas
dele, com alimento e porção originais ao lado. "Confirmar troca" grava na hora
pelo `PATCH`. Recusa do servidor mostra a mensagem e recarrega o plano.

### Q20 — Se Q7 = a): o calendário deixa abrir dias fora dos períodos?

➡️ Só dias dentro de algum plano ou prescrição de `calendar-periods` (`plans`,
`prescriptions`) e dias com execuções livres (`freeExecutionDates`). Os outros
ficam desabilitados.

### Q21 — Se Q11 decidido: o que faz a tela de atualização obrigatória (`426 CLIENT_OUTDATED`)?

➡️ Tela bloqueante com a mensagem pedindo para atualizar o app, sem link, já
que não há APK distribuído. A versão mínima sobe no servidor só quando houver
quebra de contrato.

### Q22 — Se Q12 decidido: o aceite é uma tela só para os dois documentos?

➡️ Sim. Uma tela com os dois textos e um botão "Aceitar", que faz um `POST` por
documento e depois repete a requisição que foi bloqueada. O aceite vem depois
da troca de senha do primeiro acesso, como o servidor exige. Num
`409 CONSENT_VERSION_MISMATCH`, o app relê `GET /me/consents` e tenta de novo.

### Q24 — Se Q2 = a): o que o app mostra para o paciente sem prescrição (A-01)?

Encerrar o vínculo (S-07) ou arquivar a versão vigente deixa o paciente sem
prescrição. Os planos já gerados continuam até o fim, mas gerar ou regenerar
responde `404 WEEKLY_PLAN_NOT_FOUND`. Pela rota de categorias, esse caso não se
distingue dos outros bloqueios: as quatro categorias vêm com
`NO_ALLOWED_FOODS`.

➡️ O app consulta `GET /patients/me/prescriptions/current`. Se vier
`404 PRESCRIPTION_NOT_FOUND`:

- **Início:** num dia sem plano, mostra um estado vazio único no lugar das
  quatro categorias bloqueadas: "Você não tem um plano ativo no momento. Seu
  nutricionista publica um novo plano por aqui." Num dia coberto por um plano
  ainda em curso, as categorias seguem normais, porque o modo fica congelado no
  plano.
- **Semana:** a ação "Regenerar" não aparece, e o mesmo estado vazio aparece
  quando não há plano.
- **Perfil:** o cartão de prescrição (Q8) mostra o estado vazio.

Um `404 WEEKLY_PLAN_NOT_FOUND` na geração também leva a esse estado, como
proteção. Nenhuma mudança de servidor é necessária.

---

## Rodada 3 — depende da rodada 2

### Q23 — Ordem final de implementação

➡️ O caminho crítico da demonstração (itens 1 a 3) vem primeiro.

1. Sessão por cookies (M-01), `X-Client-Version` (M-11) com a tela de `426`,
   aceite de termos (M-12) e primeiro acesso só com a nova senha (A-04).
2. Início com `daily-meal-categories` (M-10), várias execuções e estado do
   servidor (M-03), nomes do A-05, registro sem refeição planejada, remover
   com Desfazer, `calendar-periods` e remoção de "não realizada".
3. Paciente sem prescrição (Q24, A-01).
4. Mensagens por código de erro (M-02), `409` de geração, plano ativo e
   histórico (M-05).
5. Prescrição no Perfil.
6. Substituição na Semana.
7. Exclusão de plano e troca de senha pelo Perfil.
8. Testes de unidade e de widget (Q14).

---

## Registro das respostas

| Pergunta | Resposta | Data |
|---|---|---|
| Q1 | a), com o pedido P-02 ao servidor | 2026-11-16 |
| Q2 | a) | 2026-11-16 |
| Q3 | Lista de compras fora do MVP | 2026-11-16 |
| Q4 | a) | 2026-11-16 |
| Q5 | Sim, com confirmação | 2026-11-16 |
| Q6 | Remover com Desfazer; mover fora | 2026-11-16 |
| Q7 | a) | 2026-11-16 |
| Q8 | Recomendação, com o estado vazio da Q24 | 2026-11-16 |
| Q9 | Fora do MVP, mesmo com a rota existente | 2026-11-16 |
| Q10 | Fora do MVP | 2026-11-16 |
| Q11 | Android com build local; sem APK de staging | 2026-11-16 |
| Q12 | Texto preliminar com a frase do A-02 | 2026-11-16 |
| Q13 | Sim, com dois modos de tela (A-04) | 2026-11-16 |
| Q14 | Verificação local; sem CI nem teste integrado | 2026-11-16 |
| Q15 | Recomendação, com os nomes do A-05 | 2026-11-16 |
| Q16 | Recomendação | 2026-11-16 |
| Q17 | Recomendação | 2026-11-16 |
| Q18 | Não se aplica (Q3) | 2026-11-16 |
| Q19 | Recomendação | 2026-11-16 |
| Q20 | Recomendação | 2026-11-16 |
| Q21 | Tela bloqueante sem link | 2026-11-16 |
| Q22 | Recomendação | 2026-11-16 |
| Q23 | Ordem acima | 2026-11-16 |
| Q24 | Recomendação | 2026-11-16 |
