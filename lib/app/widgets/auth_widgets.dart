import 'package:flutter/material.dart';
import '../theme/vv2/vv_icons.dart';
import '../theme/vv2/vv2_tokens.dart';

const _kBorder = Color(0xFF6E4B3E);

/// Estrutura das telas Criar conta / Entrar: cabeçalho em degradê com botão de
/// voltar, logo e título; painel creme com cantos arredondados; o pet apoia as
/// patinhas na borda do painel. O conteúdo rola (teclado aberto, texto 130%).
class AuthShell extends StatelessWidget {
  final String title;
  final String petAsset;
  final double petAspect; // largura / altura da arte
  final double petShift; // afasta o pet da borda direita (evita o logo)
  final List<Widget> children;
  const AuthShell({
    super.key,
    required this.title,
    required this.petAsset,
    required this.petAspect,
    this.petShift = 0,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scale = mq.textScaler.scale(16) / 16;
    // Com texto grande, a foto diminui antes de qualquer outra coisa.
    final petH = scale > 1.15 ? 112.0 : 148.0;
    final petW = petH * petAspect;
    const overlap = 10.0; // patinhas sobre a borda do painel
    final canBack = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: Vv2Pastel.cream,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFDCC8), Color(0xFFFFA06A)],
              ),
            ),
            constraints:
                BoxConstraints(minHeight: mq.padding.top + 48 + petH * 0.62),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(Vv2.gutter, 8, Vv2.gutter, 46),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (canBack)
                          Semantics(
                            button: true,
                            label: 'Voltar',
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).maybePop(),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                    color:
                                        Vv2Pastel.cream.withValues(alpha: 0.9),
                                    shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: const VvIcon(VvFn.back,
                                    size: 22, color: Vv2.text),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 48, height: 48),
                        const Spacer(),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset('assets/images/logo_light.png',
                              width: 58,
                              height: 58,
                              excludeFromSemantics: true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: EdgeInsets.only(right: petW + petShift + 8),
                      child: Text(title, style: Vv2.t(28, 36, 700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Vv2Pastel.cream,
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(Vv2.rOverlay + 8)),
                    ),
                    transform: Matrix4.translationValues(0, -overlap - 14, 0),
                  ),
                ),
                Positioned.fill(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                        Vv2.gutter + 4, 6, Vv2.gutter + 4, 24),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: Vv2.gutter + 4 + petShift,
                  top: -petH + 14 - overlap,
                  child: IgnorePointer(
                    child: Image.asset(petAsset,
                        height: petH,
                        width: petW,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão em pílula: variantes degradê (principal), branco com contorno
/// (Google) e preto (Apple). Mantém a largura no estado de carregamento.
enum VvPillKind { primary, outlined, black }

class VvPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final VvPillKind kind;
  final Widget? leading;
  final bool loading;
  /// Círculo com seta à direita (CTA de avançar).
  final bool arrow;
  const VvPillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = VvPillKind.primary,
    this.leading,
    this.loading = false,
    this.arrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = kind == VvPillKind.black ? Colors.white : Vv2.onBrand;
    final disabled = onTap == null;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: disabled && !loading ? 0.6 : 1,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: arrow
                ? const EdgeInsets.fromLTRB(24, 6, 6, 6)
                : const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              gradient: kind == VvPillKind.primary ? Vv2.ctaGradient : null,
              color: kind == VvPillKind.outlined
                  ? Colors.white
                  : kind == VvPillKind.black
                      ? const Color(0xFF1A1A1A)
                      : null,
              border: kind == VvPillKind.outlined
                  ? Border.all(color: _kBorder)
                  : null,
              borderRadius: BorderRadius.circular(Vv2.rPill),
            ),
            child: loading
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: fg),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leading != null) ...[
                        leading!,
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        fit: arrow ? FlexFit.tight : FlexFit.loose,
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style: Vv2.t(16, 22, 700, color: fg)),
                      ),
                      if (arrow)
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Vv2.surface.withValues(alpha: 0.7),
                            shape: BoxShape.circle,
                          ),
                          child: VvIcon(VvFn.forward, size: 20, color: fg),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Divisor "ou".
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            const Expanded(child: Divider(color: Vv2.divider, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('ou', style: Vv2.t(14, 20, 600)),
            ),
            const Expanded(child: Divider(color: Vv2.divider, thickness: 1)),
          ],
        ),
      );
}

/// Link de texto (alvo mínimo de 48).
class AuthTextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AuthTextLink(this.label, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(Vv2.tapMin)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: Vv2.t(15, 20, 700, color: Vv2.primary)),
      );
}

/// Campo do formulário de Entrar: rótulo persistente, contorno e 56 de altura.
InputDecoration authFieldDecoration(String label, IconData icon,
    {Widget? suffix}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Vv2.rPill),
      borderSide: BorderSide(color: c, width: w));
  const err = Color(0xFFB3261E);
  return InputDecoration(
    labelText: label,
    labelStyle: Vv2.t(15, 20, 400, color: Vv2.textSecondary),
    floatingLabelStyle: Vv2.t(13, 18, 600, color: Vv2.primary),
    filled: true,
    fillColor: Colors.white,
    prefixIcon: Icon(icon, color: Vv2.textSecondary),
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    border: b(_kBorder),
    enabledBorder: b(_kBorder),
    focusedBorder: b(Vv2.primary, 2),
    errorBorder: b(err),
    focusedErrorBorder: b(err, 2),
    errorStyle: Vv2.t(12, 16, 500, color: err),
  );
}

/// Símbolo do Google (o mesmo já usado pelo app).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 22,
        height: 22,
        child: CustomPaint(painter: _GoogleLogoPainter()),
      );
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = w / 2;

    // Red arc (top-right going clockwise from ~315° to ~45°)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -2.35, 1.57, false,
      Paint()
        ..color = const Color(0xFFEA4335)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.22
        ..strokeCap = StrokeCap.butt,
    );
    // Green arc (bottom-right)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -0.78, 1.57, false,
      Paint()
        ..color = const Color(0xFF34A853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.22
        ..strokeCap = StrokeCap.butt,
    );
    // Yellow arc (bottom-left)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      0.79, 1.2, false,
      Paint()
        ..color = const Color(0xFFFBBC05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.22
        ..strokeCap = StrokeCap.butt,
    );
    // Blue arc (left side)
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      1.99, 1.18, false,
      Paint()
        ..color = const Color(0xFF4285F4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.22
        ..strokeCap = StrokeCap.butt,
    );

    // Blue horizontal bar (the middle bar of the G)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx, cy - h * 0.12, w * 0.5, h * 0.24),
        const Radius.circular(2),
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter oldDelegate) => false;
}
