# Plano de implementação — redesign do Prato em Dia

## Produto e direção

Aplicativo Flutter adaptativo para iOS e Android, usado pelo paciente para
executar uma prescrição preparada por nutricionista. A experiência deve
parecer uma rotina guiada: superfícies claras e quentes, verde profundo para
ação e seleção, tipografia compacta e legível, listas densas com divisores e
cartões apenas quando delimitarem uma unidade real. O tema escuro não faz parte
desta entrega.

O app mantém Cubits, repositórios, Dio e navegação imperativa já existentes.
Não introduzir `go_router`, contêiner de injeção de dependências ou cache como
parte do redesign. Regras clínicas, prescrição e substituições autorizadas
continuam sob autoridade do backend.

## Navegação

- Renomear Hoje para Início e iniciar sempre na data atual.
- Exibir apenas Início, Semana e Perfil na navegação persistente.
- Remover a ação global de registrar alimento e qualquer destino de Compras.
- Integrar a barra inferior à área segura, mantendo rótulo e ícone no destino
  ativo, contraste e alvos de pelo menos 48 dp. Ocultá-la quando o teclado
  estiver aberto e respeitar os gestos do sistema.

## Sistema visual e componentes

Implementar tokens para cores, papéis tipográficos, espaçamento, raios,
elevação, estados e foco. Acessibilidade inclui fonte ampliada, leitor de tela,
contraste e redução de movimento. Criar primitivas compartilhadas para
cabeçalho contextual, status textual com ícone, carregamento/erro/vazio/sucesso,
linha de lista, item de refeição, ação principal, confirmação e bottom sheet.

## Superfícies e fluxos

1. **Entrada:** refinar bootstrap, login, ajuda de acesso e troca obrigatória de
   senha. Preservar autofill e validação; associar erros aos campos e separar a
   saída da ação de salvar senha.
2. **Início:** calendário entre períodos disponíveis, estado sem plano, resumo
   de calorias e macronutrientes realizado versus prescrito, refeições em ordem
   de horário, progresso e entrada contextual no detalhe da refeição. Limitar
   visualmente barras a 100% sem ocultar valores excedentes.
3. **Semana:** destacar o plano vigente, navegar dias e refeições em drill-down;
   gerar ou regenerar sem etapa de confirmação.
4. **Execuções:** mostrar execuções no detalhe da refeição; criar, editar,
   remover e realocar para qualquer data/refeição do plano vigente; permitir
   editar todos os campos. Remover imediatamente com Desfazer por cinco
   segundos e restauração persistida. Preservar modos restrito, substituições
   autorizadas e livre.
5. **Catálogo:** rota contextual da refeição, busca remota por `q`, paginação,
   linhas escaneáveis, detalhe de porção e estados coerentes.
6. **Perfil:** separar identidade, edição, vínculo profissional e sessão;
   manter logout isolado.

## Dados e integração

Preservar integrações existentes. Até existirem contratos remotos, usar
adaptadores simulados somente para resumo nutricional diário, períodos
disponíveis, busca paginada por termo e execuções editáveis/restauráveis. Os
adaptadores devem implementar interfaces intercambiáveis por fontes remotas e
não inventar recomendações clínicas.

## Dependências de backend

Ver [dependências-backend-redesign.md](dependencias-backend-redesign.md). O app
deve trocar cada adaptador simulado pela integração remota quando o contrato
correspondente existir.

## Validação

Executar a suíte Flutter existente e atualizá-la quando a interface mudar.
Validar em iPhone e Android compactos: fonte ampliada, leitor de tela,
contraste, teclado, áreas seguras, estados assíncronos, calendário, metas,
catálogo, edição, remoção/desfazer e navegação. A verificação manual em
dispositivos depende de simuladores/emuladores disponíveis no ambiente.

## Ordem de implementação

1. Tokens e componentes semânticos.
2. Navegação de três destinos e Início com estados coerentes.
3. Semana e detalhe de refeições.
4. Execuções editáveis com adaptador simulado, respeitando os modos atuais.
5. Catálogo com busca paginada simulada e Perfil.
6. Entrada e estados de autenticação.
7. Testes, revisão de acessibilidade e validação em dispositivos compactos.
