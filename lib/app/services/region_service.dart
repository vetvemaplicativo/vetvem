import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Região (UF + cidade) escolhida pelo visitante antes de ter conta/endereço.
/// Fica guardada no aparelho; quem já tem endereço cadastrado usa o endereço.
class RegionService extends GetxService {
  static const _box = 'region_choice';

  final uf = ''.obs;
  final city = ''.obs;

  bool get hasRegion => uf.value.isNotEmpty && city.value.isNotEmpty;

  String get label => hasRegion ? '${city.value} – ${uf.value}' : '';

  Future<RegionService> init() async {
    try {
      await GetStorage.init(_box);
      final b = GetStorage(_box);
      uf.value = (b.read<String>('uf') ?? '').toUpperCase();
      city.value = b.read<String>('city') ?? '';
    } catch (_) {
      // Sem armazenamento: o visitante só escolhe de novo na próxima abertura.
    }
    return this;
  }

  Future<void> set(String newUf, String newCity) async {
    uf.value = newUf.trim().toUpperCase();
    city.value = newCity.trim();
    try {
      final b = GetStorage(_box);
      await b.write('uf', uf.value);
      await b.write('city', city.value);
    } catch (_) {}
  }
}
