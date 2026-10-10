# Aplicativo Flutter do paciente

## Estado atual do worktree

Implementado: login, persistência segura de sessão, renovação de sessão,
logout e troca obrigatória de senha. A navegação do paciente oferece Hoje,
Minha semana e Perfil. Hoje lê refeições planejadas e registra realização ou
não realização; Minha semana lista, gera, confirma e consulta planos e edita a
preferência de geração; Perfil consulta e edita dados pessoais e mostra o
vínculo ativo. A API é acessada por `Dio`; estado usa Cubits com
`flutter_bloc`.

Ainda ausente: leitura detalhada da prescrição, substituição autorizada,
compras e histórico dedicado. As telas devem partir dos contratos reais da
API, sem apresentar como existente um endpoint de roadmap.

## Direção arquitetural

Organizar por feature, com camadas leves:

```text
feature/
  presentation/  páginas, widgets, Cubit/Bloc e estado
  domain/        modelos estáveis e contrato do repositório
  data/          API, DTOs, mapeamento e implementação
```

Cubits servem como padrão para carregamentos e comandos diretos. Bloc é
justificado apenas quando eventos concorrentes precisam de controle explícito —
por exemplo, troca rápida de semana e salvamentos concorrentes. A UI lê estado
imutável e dispara intenções; regras de domínio continuam no backend.

O documento de arquitetura propõe `get_it` para composição, `go_router` para
rotas, cache online-first e `shared_preferences` apenas para preferências e
checklist local. Essas escolhas ainda não foram instaladas neste repositório e
devem ser introduzidas incrementalmente, se confirmadas.

## Navegação alvo

Após bootstrap/autenticação, a barra inferior tem três destinos disponíveis:

1. Hoje — refeições da data civil atual e ações de execução.
2. Minha semana — planos, refeições e geração automática.
3. Perfil — dados pessoais, vínculo e sessão.

Compras depende de contrato ainda não disponível no backend. Histórico
dedicado e substituições ainda não têm telas. O paciente não tem telas de
nutricionista ou administrador.

## Comportamentos essenciais

- Access token fica em memória; refresh token em `flutter_secure_storage`.
- Refresh concorrente deve ser single-flight; falha limpa a sessão e leva ao
  login.
- Preservar dados visíveis durante atualização e oferecer repetição em erros de
  rede.
- Tratar 401 com um refresh controlado; 403 sem derrubar sessão; 404 voltando a
  contexto seguro; 409 recarregando e pedindo nova confirmação.
- No registro de realização, gerar e reutilizar `Idempotency-Key` por intenção
  durante tentativas da mesma operação.
- A marcação “comprado” é preferência local por usuário/plano/item/revisão; não
  altera o conteúdo autoritativo da lista. Após recálculo, preservar somente
  itens estáveis que ainda existam.
- Ações de realização distinguem: realizada como prescrito, realizada com
  substituição e não realizada. Elas criam eventos, não editam o plano.

## UX e acessibilidade

Material 3, pt-BR, estados explícitos de carregamento/vazio/erro, texto com
contraste adequado, alvos de toque de pelo menos 48 dp e status que não dependem
apenas de cor. Mostrar autoria, versão e data da prescrição; não exibir controles
sem comportamento implementado (por exemplo, alternância de tema escuro).
