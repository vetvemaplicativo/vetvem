import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/brazilian_states.dart';
import '../service_area_controller.dart';

/// Widget reutilizável da seleção em cascata Estado → Cidades → Bairros.
/// Usado na tela de área de atuação e, futuramente, no cadastro do
/// profissional no app VetVem Pro. Requer um [ServiceAreaController]
/// registrado via Get.
class ServiceAreaSelector extends GetView<ServiceAreaController> {
  const ServiceAreaSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('1. Em qual estado você atende?'),
        const SizedBox(height: 8),
        _buildUfField(context),
        const SizedBox(height: 24),
        Obx(() {
          if (controller.selectedUf.value.isEmpty) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('2. Em quais cidades?'),
              const SizedBox(height: 8),
              _buildCitySection(context),
              const SizedBox(height: 24),
              if (controller.selectedCities.isNotEmpty) ...[
                _sectionTitle('3. Em quais bairros?'),
                const SizedBox(height: 4),
                Text(
                  'Para cada cidade, digite os bairros onde você atende '
                  'ou marque "Atendo a cidade toda".',
                  style: Get.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                ...controller.selectedCities
                    .map((c) => _CityCard(key: ValueKey(c.ibgeId), ibgeId: c.ibgeId)),
              ],
            ],
          );
        }),
      ],
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: Get.textTheme.titleMedium);

  // ── Estado ─────────────────────────────────────────────────────────

  Widget _buildUfField(BuildContext context) {
    return Obx(() {
      final uf = controller.selectedUf.value;
      final state = brazilianStates
          .firstWhereOrNull((s) => s.sigla == uf);
      return InkWell(
        onTap: () => _showUfPicker(context),
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: const InputDecoration(
            hintText: 'Toque para escolher o estado',
            suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
          ),
          child: Text(
            state != null ? '${state.nome} (${state.sigla})' : 'Escolher estado',
            style: Get.textTheme.bodyLarge?.copyWith(
              color: state != null ? AppColors.textDark : AppColors.textLight,
            ),
          ),
        ),
      );
    });
  }

  void _showUfPicker(BuildContext context) {
    Get.bottomSheet(
      _sheetContainer(
        title: 'Escolha o estado',
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: brazilianStates.length,
          itemBuilder: (_, i) {
            final state = brazilianStates[i];
            return Obx(() {
              final selected = controller.selectedUf.value == state.sigla;
              return ListTile(
                title: Text('${state.nome} (${state.sigla})'),
                trailing: selected
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  Get.back();
                  controller.selectUf(state.sigla);
                },
              );
            });
          },
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ── Cidades ────────────────────────────────────────────────────────

  Widget _buildCitySection(BuildContext context) {
    return Obx(() {
      if (controller.isLoadingCities.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 12),
                Text('Carregando cidades…'),
              ],
            ),
          ),
        );
      }
      if (controller.cityLoadError.value) {
        return Column(
          children: [
            Text(
              'Não foi possível carregar as cidades. '
              'Verifique sua conexão.',
              style: Get.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.loadCities,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.selectedCities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: controller.selectedCities
                    .map((c) => Chip(
                          label: Text(c.nome),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () => controller.removeCity(c.ibgeId),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          labelStyle: const TextStyle(color: AppColors.primaryDark),
                          side: BorderSide.none,
                        ))
                    .toList(),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => _showCityPicker(context),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: Text(controller.selectedCities.isEmpty
                ? 'Adicionar cidades'
                : 'Adicionar mais cidades'),
          ),
        ],
      );
    });
  }

  void _showCityPicker(BuildContext context) {
    controller.citySearchController.clear();
    Get.bottomSheet(
      _sheetContainer(
        title: 'Escolha as cidades onde você atende',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: controller.citySearchController,
                decoration: const InputDecoration(
                  hintText: 'Buscar cidade…',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Flexible(
              child: Obx(() {
                final cities = controller.filteredMunicipios;
                if (cities.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhuma cidade encontrada.'),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: cities.length,
                  itemBuilder: (_, i) {
                    final city = cities[i];
                    return Obx(() => CheckboxListTile(
                          value: controller.isCitySelected(city.id),
                          activeColor: AppColors.primary,
                          title: Text(city.nome),
                          onChanged: (_) => controller.toggleCity(city),
                        ));
                  },
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: Get.back,
                child: const Text('Concluir'),
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _sheetContainer({required String title, required Widget child}) {
    return Container(
      constraints: BoxConstraints(maxHeight: Get.height * 0.75),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: Get.textTheme.titleLarge),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// Card de uma cidade selecionada: switch "cidade toda" + chips de bairros.
class _CityCard extends StatefulWidget {
  final String ibgeId;

  const _CityCard({super.key, required this.ibgeId});

  @override
  State<_CityCard> createState() => _CityCardState();
}

class _CityCardState extends State<_CityCard> {
  final _bairroController = TextEditingController();
  final _focusNode = FocusNode();
  final _controller = Get.find<ServiceAreaController>();

  @override
  void dispose() {
    _bairroController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add() {
    final error =
        _controller.addBairro(widget.ibgeId, _bairroController.text);
    if (error != null) {
      Get.snackbar(
        'Atenção',
        error,
        snackPosition: SnackPosition.TOP,
        backgroundColor: AppColors.warning,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    _bairroController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final city = _controller.selectedCities
          .firstWhereOrNull((c) => c.ibgeId == widget.ibgeId);
      if (city == null) return const SizedBox.shrink();
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_city,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(city.nome, style: Get.textTheme.titleMedium),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: AppColors.textLight),
                    tooltip: 'Remover cidade',
                    onPressed: () => _controller.removeCity(city.ibgeId),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Atendo a cidade toda',
                    style: Get.textTheme.bodyLarge
                        ?.copyWith(color: AppColors.textDark)),
                activeThumbColor: AppColors.primary,
                value: city.atendeCidadeToda,
                onChanged: (v) =>
                    _controller.toggleCidadeToda(city.ibgeId, v),
              ),
              if (!city.atendeCidadeToda) ...[
                if (city.bairros.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: city.bairros
                          .map((b) => Chip(
                                label: Text(b),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () =>
                                    _controller.removeBairro(city.ibgeId, b),
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.1),
                                labelStyle: const TextStyle(
                                    color: AppColors.primaryDark),
                                side: BorderSide.none,
                              ))
                          .toList(),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bairroController,
                        focusNode: _focusNode,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Digite um bairro e toque em +',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.add),
                        tooltip: 'Adicionar bairro',
                        onPressed: _add,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}
