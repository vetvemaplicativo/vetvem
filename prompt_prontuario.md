# Prompt para Claude Code — Feature de Prontuário Digital do Pet

Estou desenvolvendo o VetVem, um app Flutter (GetX) que conecta tutores de pets a veterinários e profissionais que atendem a domicílio. O projeto está em C:\dev\vetvem.

Quero implementar a feature de **Prontuário Digital do Pet** com um objetivo estratégico claro: esse prontuário precisa ser um ativo retido na plataforma, ou seja, algo que faz o tutor e o profissional preferirem continuar usando o app em vez de migrar o relacionamento para fora dele (WhatsApp, dinheiro, etc).

## Contexto do modelo de dados atual
Antes de criar qualquer coisa nova, primeiro explore a estrutura existente do projeto (lib/app/data ou lib/app/models, lib/app/modules) para entender quais models de Pet, Consulta/Agendamento e Usuário já existem, e me mostre um resumo do que encontrar antes de propor mudanças.

## O que o prontuário deve conter
Para cada pet, o histórico deve registrar, por consulta:
- Data, profissional responsável e tipo de serviço (consulta, banho/tosa, fisioterapia, etc)
- Peso registrado naquele dia (para gerar gráfico de evolução de peso ao longo do tempo)
- Vacinas aplicadas (nome, data, próxima dose prevista)
- Medicamentos prescritos (nome, dosagem, duração do tratamento)
- Observações clínicas em texto livre do profissional
- Anexos opcionais (foto de exame, PDF de resultado de laboratório)

## Regras de negócio importantes
1. O tutor (app VetVem) deve conseguir visualizar todo o histórico do pet, mas não editar diretamente — apenas o profissional que atendeu pode registrar o que aconteceu naquela consulta específica.
2. Cada entrada do prontuário deve ficar vinculada ao ID da consulta que foi paga e concluída dentro do app — isso é o que torna o prontuário um registro oficial e contínuo, diferente de uma anotação qualquer.
3. O prontuário continua acessível mesmo que o tutor troque de profissional — a ideia é que o histórico pertença ao pet e ao app, não ao profissional individual. Isso significa que se o tutor decidir usar outro profissional dentro do app, o histórico anterior continua visível para o novo profissional (com consentimento do tutor).
4. Quero uma tela de "Linha do tempo do pet" no app do tutor mostrando esse histórico em ordem cronológica, com cards visuais simples (ícone do tipo de evento, data, resumo).
5. No app Pro (profissional), antes de uma consulta, o profissional deve poder ver o histórico anterior do pet (se o tutor autorizou) para chegar mais preparado.

## O que NÃO quero nessa etapa
Não quero ainda lógica de exportação para PDF, não quero compartilhamento externo do prontuário, e não quero sistema de permissão granular complexo — só uma trava simples de "profissional só edita o que ele mesmo registrou".

## Entregável esperado
1. Models novos ou ajustados (ex: RegistroProntuario, EvolucaoPeso, Vacina) com os campos acima.
2. Tela de "Linha do tempo do pet" no app cliente, listando os registros em ordem cronológica.
3. Tela/formulário no app Pro para o profissional preencher o registro ao final de uma consulta concluída.
4. Persistência simples consistente com o que o projeto já está usando hoje (verifique se já existe Firebase, SQLite, ou outro backend configurado antes de sugerir uma solução nova).

Antes de implementar, me dê um plano resumido do que pretende criar/alterar, para eu confirmar antes de você escrever o código.
