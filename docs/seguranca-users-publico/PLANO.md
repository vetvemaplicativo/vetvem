# Parar de expor `users/{uid}` de profissionais (phone, e-mail, endereço, PIX)

Verificado em 2026-10-07: `firestore.rules` permite que qualquer usuário autenticado
(inclusive o login **anônimo** do portal) leia o `users/{uid}` inteiro de qualquer
profissional. Solução: vitrine `professionals_public/{uid}` só com campos públicos +
remoção da leitura cruzada de `users` (fase 3, depois que os clientes migrarem).

## Estado do código (tudo pronto, NADA deployado)

| Peça | Arquivo | Status |
|---|---|---|
| Function do espelho + backfill/reconciliação | `functions/professionals_public.js` (registrada em `functions/index.js`) | pronto, 5 testes unitários |
| Regra aditiva `professionals_public` | `firestore.rules` | pronto (só adiciona um `match`, não altera nada existente) |
| Regras da fase 3 (sem leitura cruzada) | `docs/seguranca-users-publico/firestore.rules.fase3` | pronto, **não** copiado p/ `firestore.rules` |
| App tutor lê a vitrine | `lib/app/modules/vets/vets_controller.dart`, `lib/app/modules/profile/profile_controller.dart` | pronto, `flutter analyze` sem novos avisos |
| Portal lê a vitrine | `vetvem-portal/src/lib/vets.ts` | pronto, `tsc` e `eslint` limpos |
| Testes de regras (emulador) | `functions/test/firestore_rules.test.js` | passa nas regras atuais e na fase 3 |
| Verificação em produção c/ token anônimo | `functions/test/verify_public_exposure.js` | pronto, não executado |

App Pro: **não precisa mudar** — só lê/escreve o próprio `users/{uid}` (verificado por grep).
A function de espelho reage às gravações dele.

## Campos do espelho (lista branca em `buildPublicDoc`)

`name, crmv, bio, categories, services[name,price,unit], animalSpecies, area_atuacao,
area_atuacao_keys, availableDays, availableTimes, photoBase64, photoUrl, isAvailable,
rating, reviewCount, completedCount, updatedAt`.

Desvio da sugestão original: o espelho **não tem** `accountStatus`/`blocked`. O doc
existe se e somente se o profissional está aprovado e não bloqueado (mesmo critério de
`site_sync.js`); deixou de estar → doc apagado. Assim os clientes não precisam filtrar
(e não veem o status de moderação de ninguém). `name`/`crmv` não são aparados, porque o
app tutor casa avaliações por `vetName` exato.

## Fases

### Fase 1 — espelho + backfill (sem risco para clientes existentes)
1. `firebase deploy --only functions:mirrorProfessionalPublic,functions:reconcileProfessionalsPublic,functions:reconcileProfessionalsPublicNow`
2. `firebase deploy --only firestore:rules` **com o `firestore.rules` atual** (só adiciona o
   `match /professionals_public`; necessário para os clientes novos conseguirem ler). Mostrar o diff antes.
3. Backfill: `curl -X POST -H "X-VetVem-Secret: $WP_SYNC_SECRET" <url de reconcileProfessionalsPublicNow>`
   — o JSON de resposta traz `criados` (deve ≈ nº de profissionais aprovados).
4. Conferir no console: contagem de `professionals_public` = nº de aprovados e não bloqueados.

### Fase 2 — publicar clientes
- **2a. Portal** (deploy imediato, sem loja). Testar o fluxo de agendamento ponta a ponta.
- **2b. App tutor**: release nas lojas (Android + iOS; iOS depende da Apple). Incluir na
  próxima versão (hoje 1.0.8+27 em `pubspec.yaml`; precisa de build maior).
- **2c. (opcional, decisão do Ronald) paliativo sem release de app**: depois do 2a, trocar
  a regra de leitura cruzada por `... && request.auth.token.firebase.sign_in_provider != 'anonymous'`.
  Mata o cenário descrito (raspar com token anônimo, sem cadastro) sem quebrar nenhum tutor
  logado; um atacante ainda poderia criar conta de tutor. Exige um deploy de regras antes da fase 3.

### Fase 3 — endurecer (só após adoção)
**Pré-condição:** versões antigas do app tutor leem `users` e passam a receber
`permission-denied` → lista de profissionais **vazia**. Portanto:
1. Novo app tutor aprovado e publicado nas duas lojas.
2. Subir o mínimo em `config/app_version_tutor` (`minBuildAndroid` / `minBuildIOS` = build novo).
   O `ForceUpdateGate` (`lib/app/widgets/force_update_gate.dart`) trava versões antigas com
   "Atualização necessária". Builds anteriores à existência do gate não checam nada.
3. Esperar a adoção (Play Console / App Store Connect / Analytics `app_version`) — sugestão: ≥95% dos
   tutores ativos nos últimos 14 dias na versão nova.
4. Mostrar o diff (`diff -u firestore.rules docs/seguranca-users-publico/firestore.rules.fase3`),
   copiar a fase3 sobre `firestore.rules` e `firebase deploy --only firestore:rules`.
5. Rodar a verificação abaixo. Rollback: reaplicar o `firestore.rules` anterior (a vitrine continua
   existindo, não há nada a desfazer nos dados).

Preservado na fase 3: dono lê/edita o próprio `users/{uid}`; admin lê/escreve; terceiros ainda podem
atualizar só `rating`/`reviewCount`/`completedCount` (escrita sem leitura — o app faz `update`).

## Checklist de verificação

Antes de qualquer deploy (já executado nesta sessão):
- [x] `node --test functions/test/professionals_public.test.js` — espelho nunca contém phone/email/address/pixKeys/termos/fcmToken
- [x] Emulador, regras atuais: `RULES_FILE=firestore.rules firebase emulators:exec --only firestore "node --test functions/test/firestore_rules.test.js"`
- [x] Emulador, fase 3: `RULES_FILE=docs/seguranca-users-publico/firestore.rules.fase3 ...` (Java: `C:\Program Files\Android\Android Studio\jbr`)
- [x] `flutter analyze` (tutor), `tsc --noEmit` + `eslint` (portal)

Fase 1:
- [ ] Resposta do backfill sem erros; contagem do espelho = aprovados e não bloqueados
- [ ] Alterar `rating` (ou `isAvailable`) de um profissional de teste → espelho atualiza em segundos
- [ ] Bloquear/reprovar um profissional de teste → doc some do espelho; reaprovar → volta
- [ ] `FIREBASE_API_KEY=... node functions/test/verify_public_exposure.js --phase 1` → vitrine legível e sem campos privados (informa que `users` ainda vaza)

Fase 2:
- [ ] Portal: CEP → lista de profissionais → agendar; filtro por área funciona
- [ ] App tutor novo: lista, busca, filtro por região, detalhe, avaliação (atualiza rating), agendamento

Fase 3 (depois do deploy das regras):
- [ ] `FIREBASE_API_KEY=... node functions/test/verify_public_exposure.js --phase 3` → **exit 0**: `users/{uid}` de profissional → 403 e query `users role==professional` → 403 com token anônimo; vitrine 200 sem campos privados
- [ ] Tutor logado (app novo): lista, avaliação e agendamento seguem funcionando
- [ ] Pro: login, editar perfil, pausar pedidos, ver agenda
- [ ] Painel admin (claim `admin`) ainda lista/aprova profissionais

## Achados fora do escopo (não alterados)
- `appointments`: `allow read: if request.auth != null` — qualquer anônimo lê TODOS os agendamentos
  (dados de tutores e pets). Mesma classe de problema, bem maior; o comentário nas regras já cita como dívida.
- `users` `allow update` de métricas aceita qualquer autenticado (inclusive anônimo) sobre qualquer doc
  `users/*`, e `rating` é gravável por qualquer um → avaliação forjável. Em fase futura: exigir não-anônimo
  e `resource.data.role == 'professional'`, ou mover o cálculo para Cloud Function.
- O fallback antigo `users where name == vetName` (profile_controller) já era NEGADO pelas regras atuais
  (a query não restringe `role`) — bug latente corrigido pela migração.
- O app tutor calcula rating baixando TODOS os appointments `completed` a cada snapshot (custo/privacidade).
