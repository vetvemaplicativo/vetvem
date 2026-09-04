# Checklist — Publicar VetVem (tutor) no iOS

Já feito (sem precisar de Mac):
- [x] Pasta `ios/` verificada e íntegra
- [x] App iOS registrado no Firebase (`com.vetvem.vetvem`, App ID `1:184640610145:ios:30b028de7bddeaa9caef20`)
- [x] `GoogleService-Info.plist` baixado e colocado em `ios/Runner/`
- [x] Permissões de câmera e galeria adicionadas no `Info.plist`
- [x] "Sign in with Apple" implementado no código (`auth_service.dart`, `login_controller.dart`/`login_view.dart`) — obrigatório pela Apple porque o app já oferece login com Google
- [x] `ios/Runner/Runner.entitlements` criado com a permissão de Apple Sign In (ainda precisa ser linkado no Xcode)
- [x] Git iniciado e enviado para o GitHub (`vetvemaplicativo/vetvem`)
- [x] Build de teste no Codemagic (simulador iOS, sem assinatura) — **passou sem erros** ✅
- [x] Política de privacidade já existe e está no ar em https://vetvem.com.br/privacidade

- [x] Conta Apple Developer paga e aprovada (2026-08-27)
- [x] App ID `com.vetvem.vetvem` registrado no developer.apple.com com **Push Notifications** e **Sign In with Apple** habilitados
- [x] Chave APNs criada (Key ID `3T22X4M94W`, Team ID `X3K2T22232`, ambiente Sandbox & Production) e enviada ao Firebase Console → Cloud Messaging (dev + produção)

- [x] Build assinado real gerado com sucesso no Codemagic (certificado "Apple Distribution" compartilhado com o Pro + perfil de provisionamento próprio, carregados manualmente nas Code Signing Identities)
- [x] Ícones iOS corrigidos (canal alpha removido — obrigatório pra App Store aceitar)
- [x] Build enviado com sucesso ao App Store Connect / TestFlight (chave de equipe, não a individual — ver nota)
- [x] `GoogleService-Info.plist` incluído de verdade no bundle do app (não estava referenciado no `project.pbxproj`)
- [x] `CODE_SIGN_ENTITLEMENTS` linkado no `project.pbxproj`
- [x] URL Scheme do Google Sign-In adicionado no `Info.plist`
- [x] Provedor "Apple" habilitado no Firebase Console → Authentication → Sign-in method
- [x] `OAuthProvider('apple.com').credential(...)` corrigido — faltava `accessToken: appleCredential.authorizationCode`
- [x] **Sign in with Apple e Google testados com sucesso no iPhone via TestFlight** ✅ (2026-09-04)
- [ ] Testar o restante do fluxo (agendamento, notificações push) em iPhone físico
- [ ] Preencher a ficha completa na App Store Connect (rascunhos em `docs/app_store/` no repo do Pro)
- [ ] Preencher "Beta App Information" e "Beta App Review Information" no TestFlight
- [ ] Enviar para revisão da Apple

Alternativa sem Mac próprio: **Codemagic** (já configurado e testado com sucesso).
