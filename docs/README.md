# Base de conhecimento — Prato em Dia

Este diretório é a referência local, curta e pesquisável do contexto de produto
e arquitetura consolidado em 17 de setembro de 2026. Ele foi criado a partir da
pasta de projeto no Google Drive e confrontado com este repositório Flutter.

## Como usar

- Comece por [produto](produto.md) para propósito, público, escopo e regras de
  negócio.
- Consulte [mobile](mobile.md) antes de criar ou alterar fluxos Flutter.
- Consulte [backend-e-contratos](backend-e-contratos.md) para saber o que a API
  já oferece e o que ainda é roadmap.
- Consulte [dados](dados.md) antes de desenhar um recurso que persista dados.
- Consulte [roadmap](roadmap.md) para prioridades e critérios de entrega.
- Consulte [plano de implementação do redesign](plano-implementacao-redesign-telas.md)
  para a direção visual e os fluxos alvo.
- Consulte [dependências de backend do redesign](dependencias-backend-redesign.md)
  antes de integrar períodos, remoção, restauração e realocação de execuções.

Estes documentos são uma síntese, não uma cópia dos originais. Quando uma
decisão precisar de precisão contratual (payload, OpenAPI ou migration), a
fonte de autoridade é o repositório/contrato do backend, não esta documentação.

## Fontes analisadas

| Documento | Situação | Última modificação no Drive |
| --- | --- | --- |
| Modelo de Dados do Servidor — Prato em Dia | referência de schema | 13 set. 2026 |
| Arquitetura do aplicativo Flutter: Prato em Dia | proposta de implementação | 13 set. 2026 |
| Arquitetura do Backend em Spring Boot — Prato em Dia | referência de backend e API | 13 set. 2026 |
| Marcos do MVP | plano acadêmico | 28 jul. 2026 |
| Plano Inicial | visão e escopo | 28 jul. 2026 |
| Pesquisa Competitiva | posicionamento e validação | 12 jul. 2026 |

## Estado verificado deste repositório

O app é Flutter, usa `dio`, `flutter_bloc` e `flutter_secure_storage`. Já há
login, restauração/renovação de sessão, logout e troca obrigatória de senha.
O ponto de entrada e a árvore de autenticação estão em `lib/main.dart`;
Hoje, semana, registro de execuções, catálogo e perfil também existem. Compras
e a leitura detalhada da prescrição ainda não.

As propostas antigas mencionam `get_it`, `go_router`, `shared_preferences`,
Freezed e alguns pacotes de teste. Eles **não** são dependências atuais no
`pubspec.yaml`; introduzi-los requer uma decisão de implementação, não deve ser
assumido como trabalho já feito.
