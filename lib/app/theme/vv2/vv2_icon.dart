import 'package:flutter/material.dart';

/// Phosphor Regular (MIT) exportado em PNG 32/64/96 px (branco, tingido aqui).
/// Mapa por função: cada tela migrada reutiliza estes nomes.
class Ph {
  Ph._();
  static const stethoscope = 'stethoscope';
  static const scissors = 'scissors';
  static const heartbeat = 'heartbeat';
  static const pawPrint = 'paw_print';
  static const syringe = 'syringe';
  static const flowerLotus = 'flower_lotus';
  static const house = 'house';
  static const search = 'magnifying_glass';
  static const calendarCheck = 'calendar_check';
  static const userCircle = 'user_circle';
  static const caretDown = 'caret_down';
  static const caretLeft = 'caret_left';
  static const caretRight = 'caret_right';
  static const check = 'check';
  static const mapPin = 'map_pin';
  static const sortAscending = 'sort_ascending';
  static const star = 'star';
  static const close = 'x';

  /// Ícones de categoria (chave do Material em [kSpecialtyIcons]) → Phosphor.
  static final _specialtyByMaterial = <IconData, String>{
    Icons.medical_services_outlined: stethoscope,
    Icons.content_cut: scissors,
    Icons.self_improvement_outlined: flowerLotus,
    Icons.psychology_outlined: 'brain',
    Icons.vaccines_outlined: syringe,
    Icons.spa_outlined: 'plant',
    Icons.monitor_heart_outlined: heartbeat,
    Icons.visibility_outlined: 'eye',
    Icons.healing_outlined: 'bandaids',
    Icons.waves_outlined: 'waves',
    Icons.biotech_outlined: 'dna',
    Icons.local_hospital_outlined: 'first_aid_kit',
    Icons.restaurant_outlined: 'fork_knife',
    Icons.science_outlined: 'flask',
    Icons.pets_outlined: pawPrint,
  };

  /// Nome Phosphor equivalente ao ícone da especialidade (null = sem par).
  static String? forSpecialty(IconData icon) => _specialtyByMaterial[icon];
}

class Vv2Icon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  final String? semanticLabel;
  final bool duotone;
  const Vv2Icon(this.name,
      {super.key,
      this.size = 24,
      required this.color,
      this.semanticLabel,
      this.duotone = false});

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/icons/phosphor/${duotone ? 'phd' : 'ph'}_$name.png',
        width: size,
        height: size,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.medium,
        semanticLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
      );
}

/// Ícone de categoria: Phosphor quando existe par, senão o Material de sempre.
class Vv2SpecialtyIcon extends StatelessWidget {
  final IconData fallback;
  final double size;
  final Color color;
  const Vv2SpecialtyIcon(this.fallback,
      {super.key, this.size = 24, required this.color});

  @override
  Widget build(BuildContext context) {
    final n = Ph.forSpecialty(fallback);
    return n == null
        ? Icon(fallback, size: size, color: color)
        : Vv2Icon(n, size: size, color: color, duotone: true);
  }
}
