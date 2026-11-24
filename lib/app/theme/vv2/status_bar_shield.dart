import 'package:flutter/material.dart';
import 'vv2_tokens.dart';

/// Quando o conteúdo rola por baixo da barra de status, pinta a faixa da
/// barra com o fundo da tela para o texto não ficar sobreposto ao relógio e
/// aos ícones do sistema. No topo da página (sem rolagem) fica transparente,
/// deixando o degradê do cabeçalho aparecer.
class StatusBarShield extends StatefulWidget {
  final Widget child;
  final Color color;
  const StatusBarShield(
      {super.key, required this.child, this.color = Vv2Pastel.cream});

  @override
  State<StatusBarShield> createState() => _StatusBarShieldState();
}

class _StatusBarShieldState extends State<StatusBarShield> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final scrolled = n.metrics.pixels > 4;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: top,
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              color: _scrolled ? widget.color : Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }
}
