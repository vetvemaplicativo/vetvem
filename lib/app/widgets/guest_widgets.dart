import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../routes/app_routes.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../theme/vv2/vv_icons.dart';
import '../theme/vv2/vv2_tokens.dart';

/// Pede conta ao visitante que tentou agendar. Guarda o profissional escolhido
/// para a Home retomar o agendamento depois do login/cadastro.
Future<void> showGuestWall({required String vetId}) async {
  final auth = Get.find<AuthService>();
  final analytics = Get.find<AnalyticsService>();
  analytics.logWallShown('agendar', vetId);
  final action = await Get.bottomSheet<String>(
    const _GuestWallSheet(),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
  );
  if (action == 'register') {
    analytics.logWallAction('criar_conta');
    auth.pendingVetId = vetId;
    Get.toNamed(Routes.register);
  } else if (action == 'login') {
    analytics.logWallAction('entrar');
    auth.pendingVetId = vetId;
    Get.toNamed(Routes.login);
  } else {
    analytics.logWallAction('dispensou');
  }
}

/// Botão principal em pílula (degradê) usado nos pedidos de conta.
class _PillCta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PillCta({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.fromLTRB(24, 6, 6, 6),
          decoration: BoxDecoration(
            gradient: Vv2.ctaGradient,
            borderRadius: BorderRadius.circular(Vv2.rPill),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: Vv2.t(17, 24, 700, color: Vv2.onBrand)),
              ),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Vv2.surface.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child:
                    const VvIcon(VvFn.forward, size: 20, color: Vv2.onBrand),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Recorta o pé da imagem pela curva dos cantos da folha: o corpo dos bichos
/// não passa da curva; só as patas (no meio) avançam sobre a borda.
class _SheetCornerClipper extends CustomClipper<Path> {
  final double sheetTop;
  final double sideMargin;
  final double radius;
  const _SheetCornerClipper(
      {required this.sheetTop, required this.sideMargin, required this.radius});

  @override
  Path getClip(Size size) {
    final above = Path()..addRect(Rect.fromLTRB(0, 0, size.width, sheetTop));
    final sheet = Path()
      ..addRRect(RRect.fromLTRBAndCorners(
        -sideMargin,
        sheetTop,
        size.width + sideMargin,
        size.height + 100,
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius),
      ));
    return Path.combine(PathOperation.union, above, sheet);
  }

  @override
  bool shouldReclip(_SheetCornerClipper old) =>
      old.sheetTop != sheetTop ||
      old.sideMargin != sideMargin ||
      old.radius != radius;
}

class _GuestWallSheet extends StatelessWidget {
  const _GuestWallSheet();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Foto decorativa: dupla apoiada na borda superior da folha.
    // Recorte largo: ~92% da largura da tela, proporção 749x480 preservada.
    final imgW = mq.size.width * 0.92;
    final imgH = imgW * 480 / 749;
    const overlap = 20.0; // patas cobrem a borda branca, sem fresta
    final maxSheet = mq.size.height * 0.9 - (imgH - overlap);
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: imgH - overlap),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxSheet),
            decoration: const BoxDecoration(
              color: Vv2.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(Vv2.rOverlay)),
            ),
            padding:
                const EdgeInsets.fromLTRB(Vv2.gutter, 28, Vv2.gutter, 12),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Vv2.brand,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Crie sua conta para agendar',
                        style: Vv2.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'É rápido: com a conta você acompanha o pedido, conversa com o '
                      'profissional e recebe o prontuário do seu pet.',
                      style: Vv2.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    _PillCta(
                        label: 'Criar conta',
                        onTap: () => Get.back(result: 'register')),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => Get.back(result: 'login'),
                      style: TextButton.styleFrom(
                          minimumSize: const Size.fromHeight(Vv2.tapMin)),
                      child: Text('Já tenho conta',
                          style: Vv2.t(15, 20, 700, color: Vv2.primary)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Sombra suave de contato sob as patas (sobre a borda branca).
        Positioned(
          top: imgH - 12,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: imgW * 0.86,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 10,
                        spreadRadius: -2,
                        offset: const Offset(0, 4)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: ClipPath(
                clipper: _SheetCornerClipper(
                  sheetTop: imgH - overlap,
                  sideMargin: (mq.size.width - imgW) / 2,
                  radius: Vv2.rOverlay,
                ),
                child: Image.asset(
                    'assets/images/tutor_pedido_conta_patinhas_largo.webp',
                    width: imgW,
                    excludeFromSemantics: true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tela das abas que dependem de conta (Consultas, Perfil) para o visitante.
class GuestGate extends StatelessWidget {
  final String heading;
  final String imageAsset;
  final String title;
  final String message;
  const GuestGate({
    super.key,
    required this.heading,
    required this.imageAsset,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Vv2Pastel.cream,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Vv2.gutter, 16, Vv2.gutter, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(heading, style: Vv2.t(28, 36, 700)),
              const SizedBox(height: 16),
              Container(
                height: 240,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFFFFEDE2), Color(0xFFFFB98A)],
                  ),
                  borderRadius: BorderRadius.circular(Vv2.rOverlay + 4),
                ),
                child: Image.asset('assets/images/$imageAsset',
                    fit: BoxFit.contain, excludeFromSemantics: true),
              ),
              const SizedBox(height: 24),
              Text(title,
                  textAlign: TextAlign.center, style: Vv2.t(24, 32, 700)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: Vv2.bodyLarge.copyWith(color: Vv2.textSecondary)),
              const SizedBox(height: 28),
              _PillCta(
                  label: 'Criar conta',
                  onTap: () => Get.toNamed(Routes.register)),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Get.toNamed(Routes.login),
                style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(Vv2.tapMin)),
                child: Text('Já tenho conta',
                    style: Vv2.t(15, 20, 700, color: Vv2.primary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
