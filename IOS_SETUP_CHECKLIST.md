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

Falta fazer (precisa de Mac + Xcode + conta Apple aprovada):
- [ ] Aguardar aprovação da conta Apple Developer (paga em 2026-08-26, prazo de até 2 dias úteis)
- [ ] Abrir `ios/Runner.xcworkspace` no Xcode (não o `.xcodeproj`)
- [ ] Rodar `flutter pub get` e `pod install`
- [ ] Configurar assinatura (Signing & Capabilities → Team da Apple Developer)
- [ ] Habilitar capability **Sign in with Apple** no Xcode (usa o `Runner.entitlements` já pronto)
- [ ] No developer.apple.com, no App ID `com.vetvem.vetvem`, habilitar "Sign In with Apple"
- [ ] Habilitar capability **Push Notifications** no Xcode (usada pelo `firebase_messaging`)
- [ ] Gerar chave APNs e subir no Firebase Console → Project Settings → Cloud Messaging
- [ ] Rodar `flutter build ipa` e testar num iPhone físico ou simulador
- [ ] Preencher ficha do app na App Store Connect (descrição, screenshots, categoria)
- [ ] Preencher formulário de App Privacy (dados coletados: nome, e-mail, telefone, CPF, endereço, foto — sem GPS, sem analytics)
- [ ] Submeter para revisão da Apple

Alternativa sem Mac próprio: **Codemagic** (já configurado e testado com sucesso).
