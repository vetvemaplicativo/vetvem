import 'package:flutter/material.dart';
import '../../theme/vv2/vv2_icon.dart';
import '../../theme/vv2/vv2_tokens.dart';

/// Barra de navegação flutuante em pílula (redesign 2.0).
class HomeNavV2 extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const HomeNavV2({super.key, required this.currentIndex, required this.onTap});

  static const _items = [
    (Ph.house, 'Início'),
    (Ph.search, 'Buscar'),
    (Ph.calendarCheck, 'Consultas'),
    (Ph.userCircle, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Vv2.gutter, 8, Vv2.gutter, 0),
        child: Container(
          constraints: const BoxConstraints(minHeight: Vv2.navMin),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Vv2.surface,
            borderRadius: BorderRadius.circular(Vv2.rPill),
            boxShadow: Vv2.overlayShadow,
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(child: _navItem(i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int i) {
    final selected = i == currentIndex;
    final (icon, label) = _items[i];
    final color = selected ? Vv2.onBrand : Vv2.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Vv2.rPill),
        onTap: () => onTap(i),
        child: Container(
          constraints: const BoxConstraints(minHeight: Vv2.navMin - 8),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? Vv2.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(Vv2.rPill),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Vv2Icon(icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Vv2.t(12, 16, selected ? 700 : 600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
