# Roadmap e critérios de entrega

## Marcos do MVP acadêmico

1. Problema, negócio e escopo: público, proposta, entrevistas, landing page e
   protótipos validados.
2. Fundação e vínculo: API/PostgreSQL/migrations, autenticação, autorização e
   vínculo nutricionista–paciente.
3. Prescrição publicada: refeições, alimentos, quantidades, substituições,
   versionamento e leitura pelo paciente.
4. Ciclo semanal: planejamento, substituição autorizada, compras, execução e
   síntese para o nutricionista — é a principal demonstração de valor.
5. Deploy e validação: ambiente seguro, backup, piloto, SUS/dados qualitativos e
   documentação acadêmica.

## Ordem prática para o Flutter

1. Consolidar identidade/sessão já iniciada.
2. Integrar prescrição vigente em modo leitura.
3. Implementar semana somente após o backend disponibilizar o contrato.
4. Acrescentar substituições e compras como atualização coordenada.
5. Acrescentar registro/histórico com idempotência e estados claros.
6. Finalizar perfil, acessibilidade, dados demonstrativos e teste integrado:
   login → prescrição → semana → substituição → compras → execução.

## Reduções permitidas se houver prazo curto

Remover primeiro histórico detalhado, indicadores administrativos não
essenciais, gerenciamento real de assinatura e refinamentos fora do fluxo
central. Cobrança, notificações e publicação em lojas permanecem fora do MVP.

## Critérios técnicos mínimos

- Testes unitários para mapeamento, sessão/refresh e estados de Cubit/Bloc.
- Testes widget de sucesso, vazio, carregamento e erro por tela.
- Teste integrado do ciclo central.
- CI com formatação, análise, testes e build Android.
- Produção/piloto com HTTPS, banco privado, SSH por chave, backup externo,
  monitoramento simples e rollback documentado.
