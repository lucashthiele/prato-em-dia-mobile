# Plano de redesign — aplicativo do paciente

## Status e objetivo

Este é um plano de alteração de UX e interface; ele **não altera nenhuma tela**. O objetivo é substituir a aparência genérica e fragmentada atual por uma experiência de produto móvel clara, calma e confiável para pacientes que executam uma orientação nutricional no cotidiano.

O produto não é um contador de calorias nem um catálogo de receitas: ele começa com um plano prescrito e transforma esse plano em uma semana e em decisões de refeição possíveis de executar. Esse fato deve ficar visível na hierarquia de todas as telas.

Base analisada: `origin/main` em `068d97f` (inclui o fluxo de registro de consumo).

## Escopo mapeado

| Área | Superfícies atuais |
| --- | --- |
| Entrada | verificação de sessão, login, ajuda de acesso, troca obrigatória de senha |
| Navegação | shell autenticado, Hoje, Semana, ação global de registrar alimento e Perfil |
| Execução do plano | Hoje, registro de consumo, editor de item, seletor de alimento |
| Planejamento | lista de planos semanais, geração, confirmação, detalhe e preferência de geração |
| Consulta | catálogo de alimentos e detalhe do alimento |
| Conta | Perfil, edição de dados, vínculo com nutricionista e saída |

## Diagnóstico da interface atual

- A mesma linguagem de `Card`, bordas de 16 px e botões ocupa quase todas as situações. Isso nivela informação importante e secundária.
- O verde derivado automaticamente do Material 3 e os ícones genéricos não compõem uma identidade própria para o produto.
- A navegação flutuante atual não deixa clara a diferença entre destinos persistentes e a ação primária de registrar um alimento, nem dá à ação central uma escolha explícita de refeição.
- As telas de Hoje, Semana e Perfil começam por títulos e listas; elas não mostram com rapidez o estado do plano, a próxima decisão ou o vínculo clínico que orienta a ação.
- Carregamento, vazio, erro e confirmação variam entre spinner, card, banner, snackbar e texto. A sensação é de telas feitas separadamente.
- Registro de consumo concentra uma tarefa importante em listas e bottom sheets pouco orientadas; modo permitido, alterações e confirmação não ficam legíveis como um único fluxo.

## Direção aprovada

### Tese

Criar uma interface de **rotina guiada**: serena, editorial e precisa. A aplicação deve parecer um caderno de acompanhamento alimentar preparado por um profissional, não um painel de métricas nem um conjunto de cartões genéricos.

### Sistema visual proposto

- Superfícies claras e quentes, com verde profundo usado somente para ação, seleção e confirmação; tons neutros e uma cor de apoio alimentar discreta para agrupamentos de refeição.
- Tipografia de sistema com hierarquia compacta e legível; títulos de contexto, dados e ações seguem papéis consistentes em vez de tamanhos arbitrários.
- Containers só quando delimitam uma unidade real: uma refeição, um plano, um vínculo ou uma decisão. Listas simples substituem cards repetidos.
- Ícones Material 3 apenas onde aceleram leitura; status sempre inclui texto, ícone e cor sem depender de uma única pista.
- Componentes nativos do sistema preservam affordances de iOS e Android. O app adapta barras, recuos, contraste, fonte e gesto de voltar por plataforma.

### Decisões estruturais aprovadas

1. **Navegação principal:** exibir somente **Hoje**, **Semana** e **Perfil**. Compras não integra a navegação até existir um fluxo de produto implementado.
2. **Ação central global:** manter **Registrar alimento** acessível em qualquer destino autenticado. Ao pressioná-la, abrir um bottom sheet de decisão para escolher a refeição do dia; só então iniciar o fluxo de registro. A ação nunca poderá levar a um estado indisponível.
3. **Catálogo:** mantê-lo como rota contextual do registro, usada para adicionar ou trocar alimentos, e não como destino da navegação principal. A tela terá busca remota por nome; ela depende de alteração de contrato no backend e não deve ser simulada filtrando somente páginas já carregadas.
4. **Identidade:** adotar a direção de **rotina guiada** descrita acima.

## Plano de alterações por superfície

### 1. Verificação de sessão

- Trocar a composição genérica de ícone e spinner por uma tela mínima de continuidade: marca, mensagem de progresso e feedback acessível.
- Não usar botão, card ou ilustração que façam o usuário acreditar que precisa tomar uma ação.
- Preservar o anúncio semântico de que a sessão está sendo verificada.

### 2. Login e ajuda de acesso

- Converter a primeira dobra em uma entrada orientada ao vínculo: deixar explícito que o acesso foi criado pelo nutricionista e que o plano será consultado após entrar.
- Em celular, priorizar formulário, marca e uma mensagem curta; reservar a narrativa expandida para largura ampla, sem duplicar benefícios em blocos decorativos.
- Usar rótulos persistentes, contraste alto e feedback de erro junto ao campo afetado; manter autofill, teclado e validações atuais.
- Transformar “Precisa de ajuda para entrar?” em uma ação de suporte claramente secundária, com conteúdo conciso e próximo do ponto de necessidade.

### 3. Troca obrigatória de senha

- Diferenciar visualmente esta etapa de um login comum: explicar por que ela é exigida, quais são os critérios de senha e o que acontece após salvar.
- Ordenar senha nova, confirmação, requisitos e ação primária como uma única tarefa, com feedback de validação progressivo.
- Manter a saída disponível, porém separada da ação de salvar para reduzir erro acidental.

### 4. Navegação autenticada

- Construir uma barra inferior moderna e coesa, inspirada na referência aprovada: superfície translúcida/material, integração cuidadosa à área segura e destaque inequívoco ao destino ativo, sem copiar sua estética de rede social ou treino.
- Exibir somente Hoje, Semana e Perfil como destinos persistentes. Compras fica fora da barra e não terá tela de preparação nesta entrega.
- Manter Registrar alimento como ação central global, visualmente distinta dos destinos mas integrada à barra. Ao tocar, apresentar um bottom sheet com as refeições elegíveis do dia, com nome, horário e estado de registro; a escolha abre o registro daquela refeição.
- O destino ativo deve usar rótulo, ícone e contraste, não somente cor. O sheet deve ter título, contexto, opções claramente tocáveis e cancelamento; não pode encobrir a área de gesto nem abrir um fluxo indisponível.
- Preservar as áreas de toque mínimas: 44 pt no iOS e 48 dp no Android; não cobrir conteúdo nem a área de gesto do sistema.

### 5. Hoje

- Abrir com um resumo de orientação: data, progresso do dia e próxima refeição relevante. A lista de refeições vem depois, organizada por horário.
- Cada refeição deve revelar de primeira o nome, horário, quantidade de itens e estado de registro; a ação é “Registrar” ou “Ver registro”, não um botão indistinto em todos os cards.
- Usar uma linha temporal ou agrupamento por momento do dia para reduzir a sequência de caixas idênticas.
- Tratar atualização por pull-to-refresh com conteúdo preservado e um indicador discreto; não apagar a agenda já visível.
- Criar estados consistentes para “sem plano hoje”, falha inicial, falha parcial de registro e sucesso de salvamento.

### 6. Registrar consumo

- Quando iniciado pela ação global, receber a refeição selecionada no sheet como contexto obrigatório; quando iniciado por Hoje, preservar o mesmo fluxo a partir da refeição tocada.
- Reestruturar como fluxo de confirmação: cabeçalho com refeição e horário, explicação do modo permitido, lista editável e resumo de impacto antes de confirmar.
- Indicar explicitamente o que é prescrito, substituição autorizada, item removido e item adicionado. Não usar apenas a cor para essa diferença.
- Para modo restrito, retirar affordâncias de edição que não terão efeito; para substituições, mostrar somente alternativas permitidas; para modo livre, tornar adição, troca e remoção visivelmente deliberadas.
- Fixar a ação de confirmar consumo fora da área de rolagem e manter o resumo de itens validáveis próximo dela.
- Padronizar os sheets de edição e de seleção: título, contexto, campo/seleção, ação primária e cancelar. Teclado não pode encobrir a confirmação.
- Preservar a regra de idempotência, o retorno seguro para Hoje e o tratamento de conflito 409.

### 7. Minha semana: lista e geração

- Tornar o plano vigente o foco visual: período, situação de confirmação e próxima ação aparecem antes do histórico.
- Separar “gerar nova semana” de “consultar planos anteriores”; a geração deve explicar que parte da prescrição publicada e não a altera.
- Tratar o estado vazio como primeiro passo útil, com uma única ação e explicação curta.
- Representar preferência de geração como configuração contextual e não como card equivalente a um plano de refeição.

### 8. Minha semana: detalhe e confirmação

- Apresentar uma visão por dias com resumo da semana; abrir refeições em drill-down ou expansão progressiva para não transformar o detalhe numa lista indiferenciada.
- Mostrar origem, versão e período do plano. A confirmação deve explicar a consequência e solicitar decisão clara quando ela for irreversível no contexto.
- Preservar retorno para a lista, atualização e estados de erro sem perder o conteúdo carregado.

### 9. Catálogo de alimentos

- Disponibilizar o catálogo apenas como rota contextual de adicionar ou trocar alimento dentro do registro de consumo; ele não é um destino da barra principal nem um cardápio autônomo.
- Incluir campo de busca por nome com resultados paginados fornecidos pelo backend. A busca só entra após o contrato remoto estar disponível; não filtrar localmente apenas os itens/páginas já carregados, pois isso produziria resultados incompletos.
- Usar linhas de lista densas e escaneáveis para nome, marca/categoria e origem; evitar card por item.
- Adicionar estados de carregamento em esqueleto, vazio com explicação e erro com repetição contextual.
- Manter paginação progressiva e preservar o termo de busca durante carregamento, vazio, erro e retorno do detalhe.

### 10. Detalhe do alimento

- Organizar por “como usar” (porções e equivalências) antes de detalhes secundários, sem inventar recomendações nutricionais.
- Mostrar origem e categoria como metadados discretos; observações e preparo ganham seções com leitura confortável.
- Exibir nutrientes em pares rótulo–valor consistentes, capazes de suportar listas longas e unidades variadas.
- Para alimento removido, retornar ao catálogo com uma explicação; para falha recuperável, oferecer repetição no próprio contexto.

### 11. Perfil e vínculo

- Separar identidade pessoal, dados editáveis, vínculo com nutricionista e sessão em grupos de configuração reconhecíveis, sem grandes cartões decorativos.
- Dar destaque suficiente ao profissional vinculado, pois ele é a origem da prescrição, sem expor dados além do contrato existente.
- Converter edição em modo explícito com salvar/cancelar sempre visíveis; manter a seleção de data nativa.
- Posicionar saída de conta como ação destrutiva separada do conteúdo de perfil e com confirmação apenas se houver risco de perda local relevante.

## Estados e comportamento compartilhados

| Estado | Regra de redesign |
| --- | --- |
| Carregamento inicial | Esqueleto do conteúdo quando a estrutura é conhecida; indicador de progresso apenas quando não há conteúdo possível. |
| Atualização | Manter dados anteriores e indicar atualização em linha. |
| Vazio | Explicar por que não há dados e apresentar, no máximo, uma ação possível. |
| Erro | Dizer o que falhou e oferecer repetição próxima da operação; não substituir toda a tela quando houver dados preservados. |
| Sucesso | Feedback breve, textual e acessível; manter o estado resultante visível. |
| Ação bloqueada/roadmap | Não imitar um controle disponível. Usar tela ou aviso com motivo e próximo passo real. |
| Fonte e aparência | Suportar fonte ampliada, contraste e modo claro/escuro como esquemas completos. |

## Design system a planejar antes de qualquer tela

1. Tokens semânticos de cor para superfície, texto, ação, seleção, sucesso, atenção e erro em claro/escuro.
2. Escala tipográfica baseada nos papéis Material e nos estilos dinâmicos do sistema, sem tamanhos fixos por tela.
3. Primitivos compartilhados: cabeçalho de contexto, item de refeição, linha de lista, status com ícone e texto, ação primária, painel de erro, vazio e sheet de decisão.
4. Regras de espaçamento, divisores e elevação reduzida; card é exceção e não padrão de composição.
5. Especificação de acessibilidade: foco, leitura por leitor de tela, toque, contraste, fonte ampliada, estados de loading e redução de movimento.

## Sequência recomendada de implementação futura

1. Formalizar e implementar, no backend, o contrato de busca paginada de alimentos por nome; a especificação e a implementação desse contrato ficam em plano próprio do servidor.
2. Construir tokens e primitivos semânticos, com temas claro e escuro.
3. Redesenhar entrada e navegação autenticada, incluindo a barra de três destinos e a ação global Registrar alimento.
4. Redesenhar Hoje e registro de consumo, validando ambos os pontos de entrada: uma refeição em Hoje e a escolha de refeição no bottom sheet global.
5. Redesenhar Semana e confirmação.
6. Após a disponibilidade do contrato de busca, redesenhar Catálogo e detalhe como fluxo contextual de alteração/adicionamento de alimentos; então redesenhar Perfil.
7. Validar em iPhone e Android compactos; adicionar tablet/large-screen somente se o produto passar a oferecê-lo.

## Critérios de aceite do futuro redesign

- Uma pessoa entende, em poucos segundos, qual é a próxima refeição e como registrar o que ocorreu.
- A origem profissional do plano e a diferença entre prescrito, planejado e realizado nunca são ambíguas.
- A barra principal exibe somente Hoje, Semana e Perfil; Compras não aparece como destino ou ação enquanto não houver fluxo implementado.
- Registrar alimento está disponível globalmente e, antes de abrir o registro, permite escolher uma refeição elegível em um bottom sheet acessível e cancelável.
- O catálogo é acessado somente para adicionar ou trocar alimentos no contexto de uma refeição; a busca por nome consulta o backend com paginação e nunca apresenta como resultado apenas o subconjunto já carregado no aparelho.
- Não há destino, botão ou controle que simule uma funcionalidade indisponível.
- Cada fluxo tem estados de carregamento, vazio, erro e sucesso coerentes e acessíveis.
- A interface funciona com fonte ampliada, modo claro/escuro, leitor de tela e alvos de toque nativos.
- A navegação e os gestos respeitam iOS e Android; a identidade aparece em cor, conteúdo e ritmo, não em controles reinventados.

## Fora deste plano

- Alteração de contratos, regras de domínio, cálculo de compras ou permissões. A busca paginada de alimentos por nome é uma dependência explícita deste redesign e será especificada e planejada separadamente no servidor.
- Criação de funções ainda não implementadas no backend.
- Mudança de conteúdo clínico, prescrição ou substituições autorizadas.
- Implementação de qualquer alteração descrita neste documento.
