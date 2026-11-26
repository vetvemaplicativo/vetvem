import 'package:flutter/material.dart';
import '../../../../theme/vv2/vv_icons.dart';
import '../../../../theme/vv2/vv2_tokens.dart';

/// Peças visuais do cadastro por e-mail (mockups aprovados 26/11).

const _kFieldBorder = Color(0xFF8A6A5C);
const kRegError = Color(0xFFB3261E);

/// Campo com rótulo sempre visível dentro da borda, como nos mockups.
/// O erro aparece em texto logo abaixo (não depende só da cor).
InputDecoration regDecoration(String label,
    {String? errorText, Widget? suffix, String? hint}) {
  InputBorder b(Color c, double w) =>
      _BoxBorder(BorderSide(color: c, width: w));
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    floatingLabelBehavior: FloatingLabelBehavior.always,
    labelStyle: Vv2.t(14, 18, 500, color: Vv2.textSecondary),
    floatingLabelStyle: Vv2.t(14, 18, 600, color: Vv2.textSecondary),
    hintStyle: Vv2.t(16, 22, 400, color: Vv2.outline),
    errorStyle: Vv2.t(13, 18, 600, color: kRegError),
    errorMaxLines: 3,
    filled: true,
    fillColor: Vv2.surface,
    counterText: '',
    contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    suffixIcon: suffix,
    enabledBorder: b(_kFieldBorder, 1),
    focusedBorder: b(Vv2.primary, 2),
    errorBorder: b(kRegError, 1.5),
    focusedErrorBorder: b(kRegError, 2),
    border: b(_kFieldBorder, 1),
  );
}

/// Cabeçalho em degradê: voltar, logo, "Passo N de 3", título e progresso.
class RegHeader extends StatelessWidget {
  final int step; // 0..total-1
  final int total;
  final String title;
  final VoidCallback onBack;
  const RegHeader({
    super.key,
    required this.step,
    required this.total,
    required this.title,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: Vv2.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Vv2.gutter, 8, Vv2.gutter, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Voltar',
                    excludeSemantics: true,
                    child: Material(
                      color: Vv2.surface.withValues(alpha: 0.85),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onBack,
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: VvIcon(VvFn.back,
                                size: 22, color: Vv2.onBrand),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Image.asset('assets/images/logo_light.png',
                      width: 40, height: 40, excludeFromSemantics: true),
                ],
              ),
              const SizedBox(height: 16),
              Text('Passo ${step + 1} de $total',
                  style: Vv2.t(14, 20, 700, color: Vv2.onBrand)),
              const SizedBox(height: 4),
              Semantics(
                header: true,
                child: Text(title, style: Vv2.t(30, 38, 700)),
              ),
              const SizedBox(height: 14),
              ExcludeSemantics(
                child: Row(
                  children: [
                    for (var i = 0; i < total; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 5,
                          decoration: BoxDecoration(
                            color: i <= step
                                ? const Color(0xFF6B3A20)
                                : Vv2.surface.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opção em pílula (espécie, sexo). Alvo mínimo de 48.
class RegChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  const RegChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? Vv2.pressedSurface : Vv2.surface,
        shape: StadiumBorder(
          side: BorderSide(
              color: selected ? const Color(0xFF6B3A20) : _kFieldBorder,
              width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Flexible(
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: Vv2.t(15, 20, selected ? 700 : 600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha de opções que vira coluna quando não cabe (tela estreita ou 130%).
class RegChoiceRow extends StatelessWidget {
  final List<Widget> children;
  const RegChoiceRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final narrow = MediaQuery.sizeOf(context).width < 370 || scale > 1.25;
    if (narrow && children.length > 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

Widget regSectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Vv2.t(15, 20, 700)),
    );

Widget regSubtitle(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(text, style: Vv2.t(15, 22, 400, color: Vv2.textSecondary)),
    );

/// Linha de dois campos que empilha com texto grande ou tela estreita.
class RegPair extends StatelessWidget {
  final Widget a;
  final Widget b;
  final int flexA;
  const RegPair({super.key, required this.a, required this.b, this.flexA = 3});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    if (scale > 1.25 && flexA > 1) {
      return Column(children: [a, const SizedBox(height: 14), b]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: flexA, child: a),
        const SizedBox(width: 10),
        Expanded(child: b),
      ],
    );
  }
}

/// Rolagem padrão das etapas: margens, espaço da barra de gestos.
class RegScroll extends StatelessWidget {
  final Widget child;
  const RegScroll({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
      padding: EdgeInsets.fromLTRB(Vv2.gutter, 28, Vv2.gutter,
          24 + MediaQuery.paddingOf(context).bottom),
      child: child,
    );
  }
}


/// Caixa arredondada que não é "outline" para o Flutter: assim o rótulo
/// flutua DENTRO do campo (topo), como nos mockups, sem recorte na borda.
class _BoxBorder extends InputBorder {
  const _BoxBorder(BorderSide side) : super(borderSide: side);
  static const _r = BorderRadius.all(Radius.circular(14));

  @override
  bool get isOutline => false;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(borderSide.width);

  @override
  _BoxBorder copyWith({BorderSide? borderSide}) =>
      _BoxBorder(borderSide ?? this.borderSide);

  @override
  ShapeBorder scale(double t) => _BoxBorder(borderSide.scale(t));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_r.toRRect(rect).deflate(borderSide.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_r.toRRect(rect));

  @override
  void paint(Canvas canvas, Rect rect,
      {double? gapStart,
      double gapExtent = 0.0,
      double gapPercentage = 0.0,
      TextDirection? textDirection}) {
    final rr = _r.toRRect(rect).deflate(borderSide.width / 2);
    canvas.drawRRect(rr, borderSide.toPaint());
  }
}
