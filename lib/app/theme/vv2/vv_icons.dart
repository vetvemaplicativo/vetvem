import 'package:flutter/material.dart';
import 'vv2_icon.dart';

/// ÚNICO lugar que decide qual ícone representa cada função do Tutor.
///
/// As telas pedem `VvIcon(VvFn.xxx)` e nunca um arquivo ou `Icons.xxx`.
/// Para trocar a biblioteca (ex.: biblioteca própria da VetVem), basta mudar
/// a linha da função em [_map]: `_png('nome')` para PNG em
/// `assets/icons/phosphor/`, ou `_material(Icons.xxx)` enquanto não houver
/// substituto. Ícones de categoria de especialidade vêm de [VvIcon.specialty].
enum VvFn {
  // Navegação principal
  navHome,
  navSearch,
  navConsults,
  navProfile,
  // Ações e indicadores
  back,
  forward,
  expand,
  search,
  sort,
  check,
  location,
  notifications,
  chat,
  // Avaliação
  ratingBadge,
  ratingFilled,
  ratingEmpty,
  // Períodos de atendimento
  periodMorning,
  periodAfternoon,
  periodNight,
  // Ordenação
  sortRelevance,
  sortRating,
  sortVolume,
  sortPrice,
  // Estados vazios e substitutos
  emptySearch,
  emptyRegion,
  userFallback,
  petFallback,
}

class _Src {
  final String? png;
  final IconData? material;
  const _Src.png(this.png) : material = null;
  const _Src.material(this.material) : png = null;
}

_Src _png(String n) => _Src.png(n);
_Src _material(IconData i) => _Src.material(i);

final Map<VvFn, _Src> _map = {
  VvFn.navHome: _png(Ph.house),
  VvFn.navSearch: _png(Ph.search),
  VvFn.navConsults: _png(Ph.calendarCheck),
  VvFn.navProfile: _png(Ph.userCircle),
  VvFn.back: _png(Ph.caretLeft),
  VvFn.forward: _png(Ph.caretRight),
  VvFn.expand: _png(Ph.caretDown),
  VvFn.search: _png(Ph.search),
  VvFn.sort: _png(Ph.sortAscending),
  VvFn.check: _png(Ph.check),
  VvFn.location: _png(Ph.mapPin),
  VvFn.notifications: _material(Icons.notifications_outlined),
  VvFn.chat: _material(Icons.chat_outlined),
  VvFn.ratingBadge: _png(Ph.star),
  VvFn.ratingFilled: _material(Icons.star_rounded),
  VvFn.ratingEmpty: _material(Icons.star_outline_rounded),
  VvFn.periodMorning: _material(Icons.wb_sunny_outlined),
  VvFn.periodAfternoon: _material(Icons.wb_cloudy_outlined),
  VvFn.periodNight: _material(Icons.nights_stay_outlined),
  VvFn.sortRelevance: _material(Icons.auto_awesome_rounded),
  VvFn.sortRating: _material(Icons.star_rounded),
  VvFn.sortVolume: _material(Icons.check_circle_outline_rounded),
  VvFn.sortPrice: _material(Icons.attach_money_rounded),
  VvFn.emptySearch: _material(Icons.search_off),
  VvFn.emptyRegion: _material(Icons.location_off_outlined),
  VvFn.userFallback: _png(Ph.userCircle),
  VvFn.petFallback: _material(Icons.pets),
};

/// Ícone por função. Cor e tamanho vêm de quem usa.
class VvIcon extends StatelessWidget {
  final VvFn fn;
  final double size;
  final Color color;
  final String? semanticLabel;
  const VvIcon(this.fn,
      {super.key, this.size = 24, required this.color, this.semanticLabel});

  /// Ícone de uma categoria de especialidade (dado vindo do Firestore).
  static Widget specialty(IconData fallback,
          {double size = 24, required Color color}) =>
      Vv2SpecialtyIcon(fallback, size: size, color: color);

  /// Ícone de uma espécie atendida: arte aprovada (colorida) pelo identificador
  /// da taxonomia ou, na falta, pelo nome. Sem arte aprovada, patinha genérica.
  /// O nome da espécie sempre aparece ao lado, na tela.
  static Widget species(String key, String label,
      {double size = 24, required Color color}) {
    final asset = _speciesArt(key, label);
    if (asset == null) {
      return Vv2Icon('paw_print',
          size: size, color: color, duotone: true);
    }
    return Image.asset('assets/icons/species/sp_$asset.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true);
  }

  static String _plain(String v) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    var r = v.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      r = r.replaceAll(from[i], to[i]);
    }
    return r;
  }

  static const _speciesMap = <String, List<String>>{
    'dog': ['dog', 'cao', 'caes', 'cachorro', 'canino', 'caninos'],
    'cat': ['cat', 'gato', 'gatos', 'felino', 'felinos'],
    'bird': ['bird', 'ave', 'aves', 'passaro', 'passaros'],
    'rabbit': ['rabbit', 'coelho', 'coelhos'],
    'rodent': ['rodent', 'roedor', 'roedores'],
    'reptile': ['reptile', 'reptil', 'repteis'],
    'fish': ['fish', 'peixe', 'peixes'],
    'exotic': ['exotic', 'exotico', 'exoticos'],
    'cavalo': ['cavalo', 'cavalos', 'horse', 'equino', 'equinos'],
    'bovinos': ['bovinos', 'bovino', 'cattle', 'bovine', 'cow', 'boi', 'vaca'],
    'caprinos': ['caprinos', 'caprino', 'goat', 'cabra', 'bode'],
    'ovinos': ['ovinos', 'ovino', 'sheep', 'ovelha', 'carneiro'],
  };

  static String? _speciesArt(String key, String label) {
    final k = _plain(key);
    final l = _plain(label);
    for (final e in _speciesMap.entries) {
      if (e.value.contains(k)) return e.key;
    }
    for (final e in _speciesMap.entries) {
      if (e.value.contains(l)) return e.key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final src = _map[fn]!;
    if (src.png != null) {
      return Vv2Icon(src.png!,
          size: size, color: color, semanticLabel: semanticLabel);
    }
    return Icon(src.material, size: size, color: color, semanticLabel: semanticLabel);
  }
}

/// Para quem precisa do IconData (ex.: ListTile.leading com cor condicional).
IconData? vvMaterialFor(VvFn fn) => _map[fn]!.material;
