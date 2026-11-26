import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/analytics_service.dart';
import '../../services/ibge_service.dart';
import '../../services/region_service.dart';
import '../../theme/vv2/vv_icons.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../../data/models/service_area_model.dart' show normalizeSearchText;
import '../../utils/brazilian_states.dart';
import '../vets/vets_controller.dart';

/// "Onde você quer o atendimento?" — escolha de Estado → Cidade do visitante,
/// sem GPS. Lista só cidades onde há profissional (vindas da vitrine pública);
/// "Minha cidade não aparece" deixa escolher qualquer cidade (a busca vazia
/// então registra a demanda e oferece a lista de espera).
class RegionPickerSheet extends StatefulWidget {
  const RegionPickerSheet({super.key});

  /// Abre o seletor. Devolve true se a pessoa escolheu uma cidade.
  static Future<bool> show() async {
    final ok = await Get.bottomSheet<bool>(
      const RegionPickerSheet(),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
    return ok == true;
  }

  @override
  State<RegionPickerSheet> createState() => _RegionPickerSheetState();
}

class _RegionPickerSheetState extends State<RegionPickerSheet> {
  final _vets = Get.find<VetsController>();
  final _region = Get.find<RegionService>();

  bool _other = false; // modo "minha cidade não aparece"
  String _uf = '';
  List<IbgeMunicipio> _municipios = const [];
  bool _loadingMunicipios = false;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _uf = _region.uf.value;
  }

  Future<void> _choose(String uf, String city, String origem) async {
    await _region.set(uf, city);
    Get.find<AnalyticsService>().logRegionSelected(uf, city, origem);
    _vets.applyRegion();
    Get.back(result: true);
  }

  /// "Minha cidade não aparece": com o estado já escolhido na lista de
  /// cidades atendidas, carrega logo os municípios dele (antes ficava vazio
  /// até a pessoa trocar o estado de novo).
  void _openOther() {
    setState(() => _other = true);
    if (_uf.isNotEmpty && _municipios.isEmpty && !_loadingMunicipios) {
      _loadMunicipios(_uf);
    }
  }

  Future<void> _loadMunicipios(String uf) async {
    setState(() {
      _loadingMunicipios = true;
      _municipios = const [];
    });
    try {
      final list = await Get.find<IbgeService>().getMunicipios(uf);
      if (!mounted) return;
      setState(() => _municipios = list);
    } catch (_) {
      // sem rede: a lista fica vazia e a pessoa pode tentar de novo
    } finally {
      if (mounted) setState(() => _loadingMunicipios = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A folha (isScrollControlled) já sobe acima do teclado; antes o código
    // somava o teclado de novo como padding e espremia tudo — campo de busca e
    // resultados sumiam com o teclado aberto. Aqui só limitamos a altura ao
    // espaço visível.
    final mq = MediaQuery.of(context);
    final teclado = mq.viewInsets.bottom;
    final maxH = (mq.size.height - teclado - mq.padding.top) * 0.92;
    return Padding(
      padding: EdgeInsets.zero,
      child: Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: Vv2.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Vv2.rOverlay)),
      ),
      padding: const EdgeInsets.fromLTRB(Vv2.gutter, 12, Vv2.gutter, 12),
      child: SafeArea(
        top: false,
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
            Text('Onde você quer o atendimento?', style: Vv2.titleLarge),
            const SizedBox(height: 4),
            Text(
              'O veterinário vai até você. Escolha a cidade para ver quem atende por lá.',
              style: Vv2.bodyMedium,
            ),
            const SizedBox(height: 16),
            Flexible(child: _other ? _buildOther() : _buildCovered()),
          ],
        ),
      ),
      ),
    );
  }

  // ── Cidades com profissional ────────────────────────────────────────────

  Widget _buildCovered() {
    return Obx(() {
      final coverage = _vets.coverageByState();
      if (_vets.isLoading.value && coverage.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (coverage.isEmpty) {
        return _OtherButton(onTap: _openOther);
      }
      final ufs = coverage.keys.toList()
        ..sort((a, b) => _stateName(a).compareTo(_stateName(b)));
      final uf = coverage.containsKey(_uf) ? _uf : ufs.first;
      final cities = coverage[uf]!.entries.toList()
        ..sort((a, b) {
          final c = b.value.compareTo(a.value);
          return c != 0 ? c : a.key.compareTo(b.key);
        });
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: uf,
            decoration: _dec('Estado'),
            icon: const VvIcon(VvFn.expand, size: 18, color: Vv2.onBrand),
            style: Vv2.titleMedium,
            borderRadius: BorderRadius.circular(Vv2.rControl),
            items: [
              for (final u in ufs)
                DropdownMenuItem(value: u, child: Text(_stateName(u))),
            ],
            onChanged: (v) => setState(() => _uf = v ?? uf),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in cities)
                  Column(children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: 8,
                      title: Text(c.key, style: Vv2.titleMedium),
                      subtitle: Text(
                        '${c.value} ${c.value == 1 ? 'profissional' : 'profissionais'}',
                        style: Vv2.bodySmall,
                      ),
                      trailing: const VvIcon(VvFn.forward,
                          size: 20, color: Vv2.onBrand),
                      onTap: () => _choose(uf, c.key, 'lista'),
                    ),
                    if (c != cities.last)
                      const Divider(height: 1, color: Vv2.divider),
                  ]),
                const SizedBox(height: 4),
                _OtherButton(onTap: _openOther),
              ],
            ),
          ),
        ],
      );
    });
  }

  // ── Minha cidade não aparece ────────────────────────────────────────────

  Widget _buildOther() {
    final shown = _municipios
        .where((m) =>
            _filter.isEmpty ||
            normalizeSearchText(m.nome).contains(normalizeSearchText(_filter)))
        .take(60)
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Com o teclado aberto o aviso sai, para sobrar espaço aos resultados.
        if (MediaQuery.of(context).viewInsets.bottom == 0) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Vv2.primaryContainer,
            borderRadius: BorderRadius.circular(Vv2.rControl),
          ),
          child: Text(
            'Ainda não temos profissional cadastrado em todas as cidades. '
            'Escolha a sua: vamos avisar você quando chegar.',
            style: Vv2.t(13, 19, 500, color: Vv2.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: 12),
        ],
        DropdownButtonFormField<String>(
          initialValue: _uf.isEmpty ? null : _uf,
          decoration: _dec('Estado'),
          icon: const VvIcon(VvFn.expand, size: 18, color: Vv2.onBrand),
          style: Vv2.titleMedium,
          borderRadius: BorderRadius.circular(Vv2.rControl),
          items: [
            for (final s in brazilianStates)
              DropdownMenuItem(value: s.sigla, child: Text(s.nome)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _uf = v;
              _filter = '';
            });
            _loadMunicipios(v);
          },
        ),
        const SizedBox(height: 8),
        if (_uf.isNotEmpty)
          TextField(
            style: Vv2.bodyLarge,
            decoration: _dec('Buscar cidade').copyWith(
              prefixIcon: const Padding(
                padding: EdgeInsets.all(14),
                child: VvIcon(VvFn.search, size: 20, color: Vv2.onBrand),
              ),
            ),
            onChanged: (v) => setState(() => _filter = v),
          ),
        if (_loadingMunicipios)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loadingMunicipios && _uf.isNotEmpty)
          Flexible(
            // Material próprio: o ListTile precisa dele para pintar o toque
            // sobre o fundo da folha (sem isso, erro no modo de depuração).
            child: Material(
              type: MaterialType.transparency,
              child: ListView(
              shrinkWrap: true,
              children: [
                for (final m in shown)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(m.nome, style: Vv2.bodyLarge),
                    onTap: () => _choose(_uf, m.nome, 'fora_da_lista'),
                  ),
              ],
            ),
            ),
          ),
        TextButton(
          onPressed: () => setState(() => _other = false),
          style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(Vv2.tapMin)),
          child: Text('Voltar para as cidades atendidas',
              style: Vv2.t(14, 20, 700, color: Vv2.primary)),
        ),
      ],
    );
  }

  InputDecoration _dec(String label) {
    OutlineInputBorder b(Color c, double w) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Vv2.rControl),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      labelText: label,
      labelStyle: Vv2.bodyMedium,
      floatingLabelStyle: Vv2.t(13, 18, 600, color: Vv2.textSecondary),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      enabledBorder: b(Vv2.primary, 1),
      focusedBorder: b(Vv2.primary, 2),
      border: b(Vv2.primary, 1),
    );
  }

  String _stateName(String uf) {
    for (final s in brazilianStates) {
      if (s.sigla == uf) return s.nome;
    }
    return uf;
  }
}

class _OtherButton extends StatelessWidget {
  final VoidCallback onTap;
  const _OtherButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(Vv2.tapMin)),
      child: Text('Minha cidade não aparece',
          style: Vv2.t(15, 20, 700, color: Vv2.primary)),
    );
  }
}
