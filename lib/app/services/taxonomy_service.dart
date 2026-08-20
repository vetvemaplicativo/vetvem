import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Uma especialidade/categoria de atendimento.
/// `label` é o texto amigável exibido nos cards (ex.: "Consulta");
/// `specialty` é o valor usado para filtrar/comparar com as categorias
/// cadastradas pelo profissional (ex.: "Clínica Geral") — os dois podem
/// diferir (ver seed original) ou ser iguais.
class SpecialtyDef {
  final String label;
  final String specialty;
  final String icon;
  final String description;

  const SpecialtyDef({
    required this.label,
    required this.specialty,
    required this.icon,
    required this.description,
  });

  factory SpecialtyDef.fromMap(Map<String, dynamic> m) => SpecialtyDef(
        label: m['label']?.toString() ?? '',
        specialty: m['specialty']?.toString() ?? m['label']?.toString() ?? '',
        icon: m['icon']?.toString() ?? 'pets_outlined',
        description: m['description']?.toString() ?? '',
      );
}

/// Uma espécie de animal atendida.
class SpeciesDef {
  final String key;
  final String emoji;
  final String label;

  const SpeciesDef({required this.key, required this.emoji, required this.label});

  factory SpeciesDef.fromMap(Map<String, dynamic> m) => SpeciesDef(
        key: m['key']?.toString() ?? '',
        emoji: m['emoji']?.toString() ?? '🐾',
        label: m['label']?.toString() ?? '',
      );
}

/// Nomes de ícone conhecidos pelo painel admin → IconData real.
/// Um nome fora deste mapa (especialidade nova sem ícone mapeado ainda)
/// cai no ícone genérico — nunca quebra a tela.
const kSpecialtyIcons = <String, IconData>{
  'medical_services_outlined': Icons.medical_services_outlined,
  'content_cut': Icons.content_cut,
  'self_improvement_outlined': Icons.self_improvement_outlined,
  'psychology_outlined': Icons.psychology_outlined,
  'vaccines_outlined': Icons.vaccines_outlined,
  'spa_outlined': Icons.spa_outlined,
  'monitor_heart_outlined': Icons.monitor_heart_outlined,
  'visibility_outlined': Icons.visibility_outlined,
  'healing_outlined': Icons.healing_outlined,
  'waves_outlined': Icons.waves_outlined,
  'biotech_outlined': Icons.biotech_outlined,
  'local_hospital_outlined': Icons.local_hospital_outlined,
  'restaurant_outlined': Icons.restaurant_outlined,
  'science_outlined': Icons.science_outlined,
  'pets_outlined': Icons.pets_outlined,
};

IconData resolveSpecialtyIcon(String name) =>
    kSpecialtyIcons[name] ?? Icons.pets_outlined;

/// Especialidades e espécies carregadas do Firestore (config/specialties,
/// config/species) — editáveis pelo painel admin, sem precisar de nova
/// versão do app. As listas abaixo são só o fallback usado enquanto a
/// primeira carga não termina (ou se falhar): nunca deixam a tela vazia.
class TaxonomyService extends GetxService {
  final specialties = <SpecialtyDef>[
    const SpecialtyDef(
      label: 'Consulta',
      specialty: 'Clínica Geral',
      icon: 'medical_services_outlined',
      description:
          'Avaliação clínica completa no conforto da sua casa. O veterinário examina seu pet, orienta sobre saúde preventiva, vacinas e exames, sem estresse do transporte.',
    ),
    const SpecialtyDef(
      label: 'Banho & Tosa',
      specialty: 'Banho & Tosa',
      icon: 'content_cut',
      description:
          'Banho, escovação, tosa higiênica ou completa feitos por profissional qualificado na sua porta. Seu pet limpo e cheiroso sem sair de casa.',
    ),
    const SpecialtyDef(
      label: 'Fisioterapia',
      specialty: 'Fisioterapia',
      icon: 'self_improvement_outlined',
      description:
          'Reabilitação e fisioterapia animal para pets em recuperação de cirurgias, fraturas ou doenças degenerativas. Sessões personalizadas no ambiente familiar do animal.',
    ),
    const SpecialtyDef(
      label: 'Adestramento',
      specialty: 'Adestramento',
      icon: 'psychology_outlined',
      description:
          'Adestramento e educação comportamental com reforço positivo. Ideal para filhotes, pets com comportamentos indesejados ou que precisam de socialização.',
    ),
    const SpecialtyDef(
      label: 'Vacinação',
      specialty: 'Vacinação',
      icon: 'vaccines_outlined',
      description:
          'Vacinação em dia sem filas e sem estresse. O profissional aplica as vacinas necessárias em casa, com toda a segurança e o registro no carteirinha do pet.',
    ),
    const SpecialtyDef(
      label: 'Acupuntura',
      specialty: 'Acupuntura',
      icon: 'spa_outlined',
      description:
          'Acupuntura veterinária para alívio de dor crônica, tratamento de doenças neurológicas, artrite e bem-estar geral. Técnica milenar aplicada por especialista certificado.',
    ),
  ].obs;

  final species = <SpeciesDef>[
    const SpeciesDef(key: 'dog', emoji: '🐶', label: 'Cão'),
    const SpeciesDef(key: 'cat', emoji: '🐱', label: 'Gato'),
    const SpeciesDef(key: 'bird', emoji: '🐦', label: 'Ave'),
    const SpeciesDef(key: 'rabbit', emoji: '🐰', label: 'Coelho'),
    const SpeciesDef(key: 'rodent', emoji: '🐹', label: 'Roedor'),
    const SpeciesDef(key: 'reptile', emoji: '🦎', label: 'Réptil'),
    const SpeciesDef(key: 'fish', emoji: '🐟', label: 'Peixe'),
    const SpeciesDef(key: 'exotic', emoji: '🦜', label: 'Exótico'),
  ].obs;

  /// Valores de especialidade únicos (para filtros/seleção) — sem duplicar
  /// quando label e specialty coincidem para itens diferentes.
  List<String> get specialtyValues =>
      specialties.map((s) => s.specialty).toSet().toList();

  Future<TaxonomyService> init() async {
    // Não bloqueia a inicialização do app — atualiza assim que chegar.
    _load();
    return this;
  }

  Future<void> _load() async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('config').doc('specialties').get();
      final items = (doc.data()?['items'] as List?)
          ?.map((e) => SpecialtyDef.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      if (items != null && items.isNotEmpty) specialties.assignAll(items);
    } catch (_) {
      // Sem rede ou doc ausente: mantém o fallback acima.
    }
    try {
      final doc =
          await FirebaseFirestore.instance.collection('config').doc('species').get();
      final items = (doc.data()?['items'] as List?)
          ?.map((e) => SpeciesDef.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      if (items != null && items.isNotEmpty) species.assignAll(items);
    } catch (_) {}
  }
}
