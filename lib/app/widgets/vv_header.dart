import 'package:flutter/material.dart';

import '../theme/vv2/vv2_tokens.dart';

/// Cabeçalho em degradê com botão de voltar circular branco e título à
/// esquerda (padrão das telas do redesign 2.0).
class VvGradientHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final IconData backIcon;
  final String backTooltip;
  /// Espaço extra embaixo quando o conteúdo sobe sobre o degradê.
  final double bottom;
  /// Ação opcional à direita (ex.: PDF).
  final Widget? trailing;
  const VvGradientHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.backIcon = Icons.arrow_back_ios_new_rounded,
    this.backTooltip = 'Voltar',
    this.bottom = 20,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: Vv2.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(Vv2.gutter, 12, Vv2.gutter, bottom),
          child: Row(
            children: [
              Material(
                color: Vv2.surface,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: backTooltip,
                  onPressed: onBack,
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: Icon(backIcon,
                      size: 20, color: Vv2.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(title, style: Vv2.t(26, 32, 700)),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
