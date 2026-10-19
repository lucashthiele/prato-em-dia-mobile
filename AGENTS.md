# AGENTS.md

## Planejamento obrigatório antes de implementar

Antes de modificar qualquer arquivo ou escrever código para resolver uma issue, você deve obrigatoriamente criar um plano de arquitetura e validá-lo com o usuário. Não prossiga com a implementação sem a aprovação explícita do plano.

O plano deve descrever:

1. **Arquivos afetados**: quais arquivos serão criados, alterados ou removidos (incluindo testes).
2. **Lógica a implementar**: o que muda em cada arquivo e por quê, incluindo decisões de design, telas/estados de UI afetados e alternativas descartadas.
3. **Riscos e pontos em aberto**: impacto em fluxos existentes, compatibilidade com a API e dúvidas que dependem do usuário.
4. **Estratégia de testes**: como a mudança será verificada (testes de unidade/widget e validação manual no app).

Fluxo:

1. Leia a issue e explore o código (somente leitura) para embasar o plano.
2. Apresente o plano ao usuário e aguarde validação.
3. Se o usuário pedir ajustes, atualize o plano e valide novamente.
4. Só então implemente, seguindo o plano aprovado. Se surgir algo que o invalide, pare e alinhe antes de continuar.
