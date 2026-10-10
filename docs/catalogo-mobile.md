# Catálogo alimentar no mobile — plano de entrega

## Objetivo

Permitir que o paciente consulte os alimentos disponíveis, suas porções e os
nutrientes fornecidos pelo catálogo do servidor. A primeira entrega é de leitura;
o cadastro e a edição de alimentos não fazem parte desta tela.

## Fluxo e interface

1. Adicionar **Catálogo** à navegação de `PatientShell`, com ícone de alimento.
2. Mostrar uma lista alfabética de alimentos ativos. Cada item exibe nome,
   marca quando houver, categoria quando houver e origem/fonte em texto discreto.
   Traduzir os valores de `origin` para rótulos em português.
3. Carregar 20 a 30 itens por página, acrescentando a página seguinte ao chegar
   ao fim da lista. Exibir indicadores separados para carga inicial e mais itens.
4. Ao tocar em um alimento, abrir uma tela de detalhes com nome, marca,
   categoria, observações e porções ativas. Cada porção mostra medida, unidade,
   equivalente em gramas quando disponível e os nutrientes recebidos da API.
   Valores não numéricos devem aparecer como “traço”, “não disponível” ou o
   status equivalente, sem serem convertidos em zero. Mapear as chaves de
   nutrientes mais comuns para rótulos em português e usar a chave recebida
   quando não houver tradução; a API não fornece nome amigável nem ordem.
5. Oferecer atualizar por gesto e tentar novamente após erro. Diferenciar
   catálogo vazio de falha de conexão. Preservar a posição da lista ao voltar
   dos detalhes ou trocar de aba.
6. Usar componentes Material 3 e textos em português; validar leitura com
   fonte ampliada e leitor de tela. Evitar cores como único sinal de estado.

## Contrato existente

- `GET /api/v1/foods?page=0&size=20`: lista apenas alimentos ativos,
  ordenados por nome; resposta `content`, `page`, `size`, `totalElements` e
  `totalPages`.
- `GET /api/v1/foods/{foodId}`: detalhes e porções, incluindo o mapa de
  nutrientes por porção. `GET /api/v1/foods/{foodId}/portions` só será necessário
  se os detalhes deixarem de incluir porções.
- Enviar o token da sessão e reutilizar a renovação após HTTP 401, como nas
  telas existentes. Tratar 404 nos detalhes como item removido e permitir voltar
  à lista atualizada.

O endpoint de listagem **não aceita busca, filtro ou ordenação enviados pelo
cliente**. Não implementar uma busca que examine apenas as páginas carregadas,
pois ela pareceria pesquisar o catálogo inteiro. Busca por nome e filtro por
categoria dependem de um contrato de pesquisa paginada no servidor; depois de
disponível, adicionar campo de busca com debounce e reiniciar a paginação a cada
consulta.

Antes de prometer paginação sem itens repetidos ou ausentes, ajustar a ordenação
do back end para usar `name, id`: hoje ela usa apenas `name`, e nomes iguais
podem trocar de posição entre páginas. O app deve deduplicar por ID como defesa,
mas isso não substitui uma ordem estável no servidor.

## Estrutura sugerida

- `features/catalog/data`: API, conversão dos JSONs e repositório com tratamento
  de sessão/erros.
- `features/catalog/domain`: modelos de alimento, porção e nutriente; contrato do
  repositório.
- `features/catalog/presentation`: estado de lista/paginação, tela de catálogo e
  tela de detalhes.

## Critérios de aceite

- A lista reflete os alimentos ativos do banco e carrega todas as páginas sem
  repetir itens; retorno dos detalhes mantém a posição anterior.
- Um item mostra seus dados e porções conforme a API, incluindo nutrientes com
  status não numérico e campos opcionais ausentes.
- Estados de carregamento, vazio, erro e token expirado têm ações claras.
- Testes de mapeamento/paginação/sessão e testes de widget cobrem lista, detalhes
  e estados principais. Validar manualmente contra o servidor com catálogo
  populado em Android ou iOS antes de concluir a entrega.

## Sequência

1. Confirmar que o banco de desenvolvimento contém dados importados e testar as
   duas consultas da API; alinhar a ordenação estável `name, id` com o back end.
2. Implementar leitura, paginação e detalhes no Flutter.
3. Validar acessibilidade e integração real app–servidor.
4. Planejar a busca global com o back end e adicioná-la após o contrato paginado.
