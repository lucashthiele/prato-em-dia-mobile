# Pedidos ao app: MVP final (sessão de 16/11/2026)

O que a sessão de fechamento do MVP do portal (`portal-web/docs/decisoes-mvp-final-2026-11-16.md`) decidiu e que muda ou afeta o app. Prazo: entrega final do TCC em 17/11/2026, sem cortes. Deploy está fora do escopo.

As mudanças de servidor citadas (S-nn) estão em `server/docs/pedidos-mvp-final-2026-11-16.md`.

## Caminho crítico da demonstração

A demonstração do TCC usa **integração real** entre o app, o servidor e o portal (Q31): o nutricionista publica, o paciente registra no app e o nutricionista vê no portal. Para isso, o app precisa ter prontos:

| Item | O que é | Referência |
|---|---|---|
| M-01 | Sessão por cookies (o servidor só lê o token do cookie) | `docs/mudancas-de-servidor.md` |
| M-12 | Aceite de termos no primeiro acesso | `docs/mudancas-de-servidor.md` |
| M-10 | Categorias do dia por `daily-meal-categories` | `docs/mudancas-de-servidor.md` |
| M-03 | Várias execuções por categoria e estado vindo do servidor | `docs/mudancas-de-servidor.md` |

A demonstração usa só contas de teste, sem dados de pessoas reais (Q32). Os textos jurídicos continuam como versão preliminar.

## Itens novos

| ID | Origem | Resumo | Trabalho no app |
|---|---|---|---|
| A-01 | S-07, S-08 (Q22b) | Paciente sem prescrição após vínculo encerrado | Sim |
| A-02 | Q33 | Frase de consentimento nos termos | Sim (texto) |
| A-03 | S-02 (Q4) | Nutricionista e admin recusados no app | Só ciência |
| A-04 | S-01 (Q2) | Senha atual opcional no primeiro acesso | Opcional |
| A-05 | Q17 | Nomes dos estados de execução | Recomendado |

### A-01: Paciente sem prescrição após vínculo encerrado

- **O que muda no servidor (S-07, S-08):** encerrar um vínculo, pelo nutricionista, pelo paciente ou pelo admin ao desativar um nutricionista, arquiva a prescrição daquele vínculo. O paciente fica sem versão vigente: os planos já gerados continuam até o fim, mas nenhum plano novo é gerado, e a geração ou regeneração responde com o erro de plano não encontrado (`WeeklyPlanNotFoundException`).
- **No app:** um estado vazio claro para "sem prescrição", diferente de "sem plano hoje", com texto como "Você não tem um plano ativo no momento. Seu nutricionista publica um novo plano por aqui." Regenerar o plano não deve aparecer como ação nesse estado.
- **Também vale** para o arquivamento da versão vigente pelo nutricionista (Q16), que já existe: o paciente termina o plano em curso e depois fica sem plano até nova publicação.

### A-02: Frase de consentimento nos termos

- Os termos preliminares do app (M-12) ganham uma frase explícita: "O nutricionista vinculado a você vê as refeições que você planeja e registra no app."
- Com isso, não há fluxo de consentimento separado no MVP. O portal coloca a mesma frase nos termos dele.

### A-03: Nutricionista e admin recusados no app

- Com o S-02, o login no app (`X-Client-Version: android/*` ou `ios/*`) de uma conta `NUTRITIONIST` ou `ADMIN` responde `401 AUTH_INVALID_CREDENTIALS`, igual a uma senha errada.
- Nenhum trabalho no app, mas testes manuais ou contas de seed que entram no app com conta de nutricionista deixam de funcionar. O app precisa enviar `X-Client-Version` com a plataforma (M-11) para a regra valer.

### A-04: Senha atual opcional no primeiro acesso

- Com o S-01, em `PATCH /me/password` a senha atual é opcional quando `passwordChangeRequired = true`.
- Opcional no app: a tela de primeiro acesso pode pedir só a nova senha e a confirmação. Mandar a senha temporária continua funcionando.

### A-05: Nomes dos estados de execução

- O portal mostra os estados por categoria como **Registrada** (`LOGGED`), **Parcial** (`PARTIAL`) e **Sem registro** (`NOT_LOGGED`), com a marca extra **Com substituição** quando algum item usou uma substituição autorizada. "Não realizada" não existe no MVP.
- Recomendado: usar os mesmos nomes no app, para o paciente e o nutricionista falarem a mesma língua. Glossário: `portal-web/GLOSSARY.md`.

## Decisões do portal que o app deve conhecer

- **Modo sugerido:** uma nova prescrição nasce com "Permitir substituições" (`SUBSTITUTIONS_ONLY`) como padrão sugerido (Q12, Q14).
- **Metas diárias** (Q13): até quatro (`energy_kcal` em kcal, `protein`, `carbohydrate` e `lipids` em g), opcionais e manuais; o app já decidiu mostrá-las ao paciente.
- **Publicação** (Q16b): uma versão nova só entra no próximo plano semanal ou quando o paciente regenera o plano. O portal avisa o nutricionista disso; o app não muda.
- **Uma refeição por categoria** (Q10): o limite de quatro categorias (Café da manhã, Almoço, Lanche, Jantar) continua no MVP; mais de um lanche fica como limitação conhecida.
