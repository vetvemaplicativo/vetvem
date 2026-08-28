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

Falta fazer (precisa de Mac + Xcode):
- [ ] Abrir `ios/Runner.xcworkspace` no Xcode (não o `.xcodeproj`)
- [ ] Rodar `flutter pub get` e `pod install`
- [ ] Configurar assinatura (Signing & Capabilities → Team da Apple Developer)
- [ ] Habilitar capabilities **Sign in with Apple** e **Push Notifications** no Xcode (usa o `Runner.entitlements` já pronto)
- [ ] Rodar `flutter build ipa` e testar num iPhone físico ou simulador
- [ ] Preencher ficha do app na App Store Connect (descrição, screenshots, categoria)
- [ ] Preencher formulário de App Privacy (dados coletados: nome, e-mail, telefone, CPF, endereço, foto — sem GPS, sem analytics)
- [ ] Submeter para revisão da Apple

Alternativa sem Mac próprio: **Codemagic** (já configurado e testado com sucesso).
