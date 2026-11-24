# Plano: Tutor em "modo visitante" (explorar antes de criar conta)

Data: 24/11/2026 · Estado: PLANO, nada implementado.

## Objetivo
Hoje quem instala o app do Tutor cai direto na tela de login/cadastro. Muitas instalações, poucas contas.
Meta: o instalador vê profissionais, serviços e preços da sua cidade ANTES de criar conta. A conta só é
exigida quando ele decide agendar.
Métrica principal: **pedidos por 100 instalações** (não "contas criadas").

## O que já existe (achados no código do Tutor)
- `splash_controller.dart`: sem usuário → `Routes.login`. É a primeira tela de quem instala.
- Login (`login_controller.dart`): Google, Apple, e-mail. Depois do login: bloqueio, Termos (`TermsView.ensureAccepted`), celular (`PhoneGate`), e `Get.offAllNamed(Routes.home)`.
- Cadastro por e-mail: 3 passos (dados pessoais com CPF e celular, endereço, pet).
- Home já tem **Categorias** (grid vindo do `TaxonomyService`, 6 visíveis + "Ver todas") e a aba **Buscar** já filtra por especialidade.
- A busca lê `professionals_public` (regra: qualquer autenticado, inclusive anônimo; é o que o portal faz) e `busyTimes` (qualquer token). **Visitante com login anônimo funciona sem mexer nas regras.**
- Região: `VetsController` usa o endereço do tutor; sem endereço, lista profissionais de TODAS as cidades (não há seletor).
- Lista de espera por região (`waitlist_regiao`) e eventos `search_no_results`/`region_empty_action` já existem em `vets_view.dart`.
- A tela de agendamento (`scheduling_controller.dart`) depende de pets e endereços do **perfil**; sem animal cadastrado ela barra ("Cadastre ao menos um animal no seu Perfil").
- ~47 usos de `FirebaseAuth.currentUser` fora do login; "currentUser != null" hoje significa "logado". Um usuário anônimo quebraria essa suposição → precisa de `isGuest`.

## Desenho

### 1. Entrada
- Splash: sem usuário → `signInAnonymously()` → Home em modo visitante. Usuário real: igual a hoje (quem atualiza o app não percebe nada).
- Ao criar conta/entrar, o anônimo é simplesmente descartado (sem `linkWithCredential`): o que ele tinha (profissional escolhido, cidade) fica guardado localmente. Evita o caso "Google já tem conta" e mantém o código simples.

### 2. `AuthService`
- `isGuest` = usuário atual é anônimo; `isLoggedIn` passa a significar "conta real".
- `requireAccount(motivo)`: abre Entrar/Criar conta e devolve `true` se a pessoa terminou o login/cadastro. Login e cadastro precisam de um modo "voltar com resultado" (hoje fazem `offAllNamed(home)`).

### 3. Home do visitante
- Cabeçalho: "Olá!" + chip da região (toca para trocar). Sino, banners, "primeira consulta" e "próximo agendamento" escondidos.
- Abas Consultas e Perfil: tela "Entre para ver suas consultas" com **Entrar** e **Criar conta**.
- Categorias: manter o grid; destacar 4 atalhos no topo (Consulta, Vacinação e as 2 mais procuradas, a definir com você) + "Ver todas".

### 4. Região sem GPS
- Novo `RegionService` (GetStorage): UF + cidade escolhidas.
- Seletor Estado → Cidade que lista **só cidades onde há profissional**, calculado da vitrine (`areaAtuacao.cidades` de cada profissional), com a contagem ("Niterói · 6 profissionais").
- "Minha cidade não aparece" → reaproveita a lista de espera que já existe.
- Aparece quando o visitante toca numa categoria ou em Buscar e ainda não há região (do endereço ou guardada).
- `VetsController`: sem endereço, usa a região guardada no filtro por cidade. Com conta, o endereço do cadastro assume (Step3 já vem com UF/cidade preenchidos).
- Fase 2 (opcional): botão "Usar minha localização" (permissão só se tocar).

### 5. Onde fica a parede de cadastro
- **Recomendado (fase 1): no botão "Agendar consulta" do perfil do profissional** (`VetsController.scheduleVet`). O visitante já viu profissional, preços, avaliações e serviços; a tela de agendamento depende do perfil (pets/endereço), então o login precisa vir antes dela.
- Depois do login/cadastro volta direto ao profissional escolhido (`selectedVet` já persiste no `VetsController`).
- Alternativa (fase 2, mais trabalho): deixar o visitante escolher serviço/data/horário e pedir a conta só no "Continuar". Exige desacoplar a tela de agendamento do perfil.

### 6. Vazamento que já existe e vira mais importante
Quem cria conta por Google/Apple chega sem animal nem endereço e cai na mensagem "Cadastre um animal no seu Perfil". Com o modo visitante isso aumenta. Adicionar passo inline no agendamento ("Qual o nome e a espécie do animal?" / "Endereço do atendimento"), sem mandar o tutor ao Perfil. (Só 29 de 77 tutores novos têm endereço hoje.)

### 7. Cuidados técnicos
- `NotificationService`: pular o salvamento do token (`users/{uid}.update`) quando o usuário é anônimo (hoje falharia em silêncio).
- Guardas `uid == null`/`isGuest` em `HomeController`, `ProfileController`, telas de Consultas e Perfil.
- Contas anônimas aparecem no Firebase Authentication, **não** na coleção `users`; o painel admin conta por `users`, então não polui. Mas o total do Auth deixa de equivaler a cadastros. (Opcional: limpeza automática de anônimos no Identity Platform.)
- Termos: o aceite continua no cadastro/login (nada muda para quem agenda). Avaliar um link "Termos" no rodapé do visitante.
- Regras do Firestore: leitura não muda. Opcional (defesa em profundidade): exigir provedor ≠ anônimo na criação de pedidos e nas functions de pagamento; checar antes que o fluxo do portal (login por celular) continua passando.
- Apple: ajuda (a diretriz 5.1.1 pede que o app não exija conta para o que não depende de conta).

### 8. Medição
Eventos novos no `AnalyticsService`: `guest_start`, `region_selected(uf, cidade, origem)`, `region_not_listed`, `wall_shown(motivo)`, `wall_converted(metodo)`, `wall_dismissed`.
Funil no Analytics: `first_open` → `region_selected` → `view_professional_profile` → `wall_shown` → `sign_up` → `booking_started` → `appointment_created`.
**Baseline antes de lançar** (14 dias): instalações (Play Console/App Store Connect), `sign_up`, pedidos, pedidos pagos.
Desinstalações: Play Console (Instalações e desinstalações), App Store Connect (Exclusões), evento `app_remove` (Android) no Firebase.

### 9. Lançamento e volta atrás
- Interruptor remoto em `config/tutor_flags` (`guestMode`): se `false`, o app usa o fluxo atual (login na primeira tela). Volta atrás sem passar pelas lojas.
- Nova versão do Tutor (1.0.25). Só quem atualizar vê o novo fluxo; Android primeiro, iOS via Codemagic.
- Comparar 2 semanas antes/depois em pedidos por 100 instalações.

## Fases
- **Fase 1 (núcleo):** entrada anônima, `isGuest`/`requireAccount`, Home visitante, região (seletor + filtro), parede no "Agendar consulta", retorno do login, guardas, eventos, interruptor. Porte: médio.
- **Fase 2:** passo inline de animal e endereço no agendamento; "usar minha localização"; avaliar parede mais tarde no fluxo. Porte: médio.
- **Fase 3:** medir 2 semanas e ajustar (atalhos, textos, onde pedir conta).

## Decisões para o Ronald
1. Parede no "Agendar consulta" do perfil do profissional (recomendado) ou depois de escolher data/horário?
2. Quais 4 atalhos no topo do Home? (Consulta, Vacinação + 2 a definir.)
3. Seletor de cidade só com cidades que têm profissional (recomendado) ou lista completa com aviso?
4. Visitante vê preços dos profissionais? (Recomendado: sim; é o gancho.)

---

## Variante B — "estilo portal" (ideia do Ronald, 24/11)
O portal (`Wizard.tsx`) já faz assim: Região → Animal → Profissional → Serviço → Endereço → Data/hora → Confirmar (nome, e-mail, celular com código por SMS) → Pix. A identificação vem por último; os dados anteriores ficam no navegador.
No app seria: o visitante escolhe região, animal e profissional, e só no "Confirmar" cria a conta, com pet e endereço já em mãos.

**Vantagens**
- A conta nasce só quando há intenção real de pagar (menos conta vazia).
- Resolve o vazamento Google/Apple sem animal/endereço: os dados já foram coletados antes.
- Cadastro vira 1 passo curto (nome, e-mail, senha, celular). `AuthService.createUserWithEmailAndPassword` já aceita `address` e `pet`; Google/Apple gravam o rascunho no perfil logo após o login.
- Perguntar a espécie cedo permite filtrar profissionais que atendem aquele animal (`animalSpecies` já vem da vitrine).

**Custos**
- É a "alternativa fase 2" do plano: `SchedulingController` hoje lê pets/endereços do `ProfileController`; precisaria ler de um rascunho local quando for visitante. Toca o caminho do pagamento, então exige mais teste.
- Pedir o animal ANTES de mostrar profissionais é mais um passo antes do valor. Sugestão: só a espécie (Cão/Gato/Outro) como chip no início; cadastro completo do animal na hora de agendar.
- `claimPortalAppointments` não é afetado (traz só consultas concluídas do portal); conferir se o CPF é exigido no pagamento.

**Recomendação:** em duas etapas. Fase 1 do plano (visitante + região + parede no "Agendar consulta") valida a hipótese em ~2 semanas com o interruptor remoto; fase 2 passa a parede para o "Confirmar" com rascunho de pet/endereço (esta variante).
