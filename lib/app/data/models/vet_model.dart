import 'service_area_model.dart';

class VetService {
  final String name;
  final String description;
  final double price;
  final String unit; // 'consulta', 'sessão', 'hora', 'pacote', 'porte'
  final int? packageSessions; // para pacotes: quantas sessões inclui

  const VetService({
    required this.name,
    required this.description,
    required this.price,
    required this.unit,
    this.packageSessions,
  });

  bool get isPackage => packageSessions != null;

  // Preço por sessão avulsa (ignora pacotes para não distorcer o "a partir de")
  double get unitPrice {
    if (isPackage) return price / packageSessions!;
    return price;
  }

  String get priceLabel {
    final formatted = 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
    if (isPackage) return '$formatted / pacote $packageSessions sessões';
    return '$formatted / $unit';
  }
}

class VetModel {
  final String id;
  final String name;
  final String crmv;
  final String specialty;
  final List<String> specialtyTags;
  final double rating;
  final int reviewCount;
  final int completedCount;
  final double cancellationRate; // 0.0 a 1.0
  final double pricePerVisit;
  final String imageUrl;
  final String photoBase64;
  final String bio;
  final List<String> availableDays;
  final List<String> availableTimes;
  final double distanceKm;
  final bool isAvailable;
  final List<String> neighborhoods;
  final List<VetService> services;
  final List<String> animalSpecies;

  /// Área de atuação estruturada (Estado → Cidades → Bairros), quando o
  /// profissional já cadastrou. Usada no filtro por endereço do tutor.
  final AreaAtuacao? areaAtuacao;

  const VetModel({
    required this.id,
    required this.name,
    required this.crmv,
    required this.specialty,
    required this.specialtyTags,
    required this.rating,
    required this.reviewCount,
    this.completedCount = 0,
    this.cancellationRate = 0.0,
    required this.pricePerVisit,
    required this.imageUrl,
    this.photoBase64 = '',
    required this.bio,
    required this.availableDays,
    required this.availableTimes,
    required this.distanceKm,
    required this.isAvailable,
    required this.neighborhoods,
    this.services = const [],
    this.animalSpecies = const [],
    this.areaAtuacao,
  });

  /// Score de ranking: 50% avaliação + 30% atendimentos + 20% taxa de cancelamento
  double get rankScore {
    // Normaliza rating de 0–5 para 0–1
    final ratingScore = rating / 5.0;
    // Normaliza completedCount com teto de 300 atendimentos
    final completedScore = (completedCount / 300.0).clamp(0.0, 1.0);
    // Taxa de cancelamento invertida (menos cancelamento = melhor)
    final cancelScore = 1.0 - cancellationRate;
    return (ratingScore * 0.5) + (completedScore * 0.3) + (cancelScore * 0.2);
  }

  // Serviços válidos: preço maior que zero
  List<VetService> get validServices => services.where((s) => s.price > 0).toList();

  // Menor preço entre os serviços avulsos válidos (ignora pacotes)
  double get startingPrice {
    final unitServices = validServices.where((s) => !s.isPackage).toList();
    if (unitServices.isEmpty) return pricePerVisit;
    return unitServices.map((s) => s.price).reduce((a, b) => a < b ? a : b);
  }

  bool get hasMultipleServices => validServices.length > 1;
}

final mockVets = [
  const VetModel(
    id: '1',
    name: 'Dra. Ana Lima',
    crmv: 'CRMV-RJ 12345',
    specialty: 'Clínica Geral',
    specialtyTags: ['Cães', 'Gatos', 'Vacinação', 'Exames'],
    rating: 4.9,
    reviewCount: 48,
    completedCount: 210,
    cancellationRate: 0.03,
    pricePerVisit: 150.0,
    imageUrl: '',
    bio: 'Médica veterinária com 10 anos de experiência em clínica geral para cães e gatos. Especialista em medicina preventiva e bem-estar animal.',
    availableDays: ['Seg', 'Ter', 'Qua', 'Qui', 'Sex'],
    availableTimes: ['09:00', '11:00', '14:00', '16:00', '18:00'],
    distanceKm: 1.2,
    isAvailable: true,
    neighborhoods: ['Botafogo', 'Flamengo', 'Catete', 'Laranjeiras'],
    services: [
      VetService(name: 'Consulta clínica', description: 'Avaliação geral do estado de saúde do pet', price: 150.0, unit: 'consulta'),
      VetService(name: 'Check-up completo', description: 'Exame físico + orientação de exames laboratoriais', price: 220.0, unit: 'consulta'),
      VetService(name: 'Retorno', description: 'Acompanhamento pós-consulta (até 30 dias)', price: 80.0, unit: 'consulta'),
    ],
  ),
  const VetModel(
    id: '2',
    name: 'Dr. Carlos Melo',
    crmv: 'CRMV-RJ 54321',
    specialty: 'Dermatologia',
    specialtyTags: ['Cães', 'Gatos', 'Alergias', 'Pele'],
    rating: 4.7,
    reviewCount: 63,
    completedCount: 145,
    cancellationRate: 0.08,
    pricePerVisit: 180.0,
    imageUrl: '',
    bio: 'Especialista em dermatologia veterinária com foco em alergias e doenças de pele. Atende cães, gatos e pequenos animais.',
    availableDays: ['Ter', 'Qui', 'Sab'],
    availableTimes: ['09:00', '10:00', '11:00', '15:00', '16:00'],
    distanceKm: 2.8,
    isAvailable: true,
    neighborhoods: ['Copacabana', 'Ipanema', 'Leblon'],
    services: [
      VetService(name: 'Consulta dermatológica', description: 'Avaliação de pele, pelagem e alergias', price: 180.0, unit: 'consulta'),
      VetService(name: 'Raspado de pele', description: 'Coleta e análise de amostra de pele', price: 240.0, unit: 'consulta'),
    ],
  ),
  const VetModel(
    id: '3',
    name: 'Dra. Marta Souza',
    crmv: 'CRMV-RJ 98765',
    specialty: 'Clínica Geral',
    specialtyTags: ['Cães', 'Gatos', 'Idosos', 'Check-up'],
    rating: 4.5,
    reviewCount: 31,
    completedCount: 68,
    cancellationRate: 0.12,
    pricePerVisit: 130.0,
    imageUrl: '',
    bio: 'Clínica geral com ênfase em medicina preventiva e acompanhamento de animais idosos.',
    availableDays: ['Seg', 'Qua', 'Sex'],
    availableTimes: ['08:00', '10:00', '14:00', '16:00'],
    distanceKm: 3.5,
    isAvailable: true,
    neighborhoods: ['Tijuca', 'Vila Isabel', 'Grajaú'],
    services: [
      VetService(name: 'Consulta clínica', description: 'Avaliação geral do estado de saúde do pet', price: 130.0, unit: 'consulta'),
      VetService(name: 'Check-up geriátrico', description: 'Avaliação completa para pets acima de 7 anos', price: 190.0, unit: 'consulta'),
      VetService(name: 'Retorno', description: 'Acompanhamento pós-consulta (até 30 dias)', price: 70.0, unit: 'consulta'),
    ],
  ),
  const VetModel(
    id: '4',
    name: 'Dr. Roberto Castro',
    crmv: 'CRMV-RJ 11223',
    specialty: 'Fisioterapia',
    specialtyTags: ['Cães', 'Reabilitação', 'Pós-cirúrgico', 'Artrite'],
    rating: 4.8,
    reviewCount: 102,
    completedCount: 280,
    cancellationRate: 0.04,
    pricePerVisit: 160.0,
    imageUrl: '',
    bio: 'Fisioterapeuta veterinário especializado em reabilitação pós-cirúrgica e tratamento de doenças degenerativas. Mais de 800 sessões realizadas.',
    availableDays: ['Seg', 'Ter', 'Qua', 'Qui'],
    availableTimes: ['10:00', '11:00', '14:00', '15:00', '16:00'],
    distanceKm: 0.8,
    isAvailable: true,
    neighborhoods: ['Barra da Tijuca', 'Recreio', 'Jacarepaguá'],
    services: [
      VetService(name: 'Sessão avulsa', description: 'Sessão individual de fisioterapia (60 min)', price: 160.0, unit: 'sessão'),
      VetService(name: 'Pacote 5 sessões', description: '5 sessões com 10% de desconto', price: 720.0, unit: 'pacote', packageSessions: 5),
      VetService(name: 'Pacote 10 sessões', description: '10 sessões com 20% de desconto', price: 1280.0, unit: 'pacote', packageSessions: 10),
      VetService(name: 'Avaliação fisioterapêutica', description: 'Avaliação inicial e elaboração do plano de tratamento', price: 120.0, unit: 'consulta'),
    ],
  ),
  const VetModel(
    id: '5',
    name: 'Lucas Ferreira',
    crmv: 'CFMV-RJ 4456',
    specialty: 'Adestramento',
    specialtyTags: ['Cães', 'Filhotes', 'Reforço positivo', 'Socialização'],
    rating: 4.9,
    reviewCount: 87,
    completedCount: 195,
    cancellationRate: 0.05,
    pricePerVisit: 120.0,
    imageUrl: '',
    bio: 'Adestrador certificado com método de reforço positivo. Especialista em filhotes, cães reativos e educação comportamental em domicílio.',
    availableDays: ['Seg', 'Qua', 'Sex', 'Sab'],
    availableTimes: ['08:00', '10:00', '14:00', '16:00'],
    distanceKm: 2.1,
    isAvailable: true,
    neighborhoods: ['Botafogo', 'Humaitá', 'Laranjeiras', 'Cosme Velho'],
    services: [
      VetService(name: 'Porte pequeno (até 10 kg)', description: 'Sessão de 1h – cães de pequeno porte', price: 100.0, unit: 'hora'),
      VetService(name: 'Porte médio (10–25 kg)', description: 'Sessão de 1h – cães de médio porte', price: 120.0, unit: 'hora'),
      VetService(name: 'Porte grande (acima de 25 kg)', description: 'Sessão de 1h – cães de grande porte', price: 150.0, unit: 'hora'),
      VetService(name: 'Consultoria comportamental', description: 'Avaliação de comportamento + plano de treinamento', price: 180.0, unit: 'consulta'),
    ],
  ),
  const VetModel(
    id: '6',
    name: 'Dra. Camila Torres',
    crmv: 'CRMV-RJ 77890',
    specialty: 'Vacinação',
    specialtyTags: ['Cães', 'Gatos', 'Vacinas', 'Antiparasitários'],
    rating: 4.8,
    reviewCount: 56,
    completedCount: 160,
    cancellationRate: 0.06,
    pricePerVisit: 90.0,
    imageUrl: '',
    bio: 'Médica veterinária com foco em medicina preventiva e vacinação domiciliar. Atende cães e gatos de todas as idades com carinho e segurança.',
    availableDays: ['Ter', 'Qui', 'Sex', 'Sab'],
    availableTimes: ['09:00', '10:00', '11:00', '15:00', '17:00'],
    distanceKm: 1.5,
    isAvailable: true,
    neighborhoods: ['Flamengo', 'Catete', 'Glória', 'Santa Teresa'],
    services: [
      VetService(name: 'V8 (cães)', description: 'Polivalente – Cinomose, Parvovirose, Hepatite e outras', price: 95.0, unit: 'dose'),
      VetService(name: 'V10 (cães)', description: 'V8 + Leptospirose e Coronavirose', price: 115.0, unit: 'dose'),
      VetService(name: 'Antirrábica', description: 'Vacina contra raiva – cães e gatos', price: 60.0, unit: 'dose'),
      VetService(name: 'Tríplice felina (gatos)', description: 'Herpesvírus, Calicivírus e Panleucopenia', price: 90.0, unit: 'dose'),
      VetService(name: 'Gripe canina', description: 'Parainfluenza e Bordetella', price: 75.0, unit: 'dose'),
      VetService(name: 'Antiparasitário', description: 'Aplicação de antipulgas / carrapatos', price: 50.0, unit: 'aplicação'),
    ],
  ),
  const VetModel(
    id: '8',
    name: 'Juliana Moraes',
    crmv: 'Cert. 8821',
    specialty: 'Banho & Tosa',
    specialtyTags: ['Cães', 'Gatos', 'Tosa higiênica', 'Tosa completa'],
    rating: 4.8,
    reviewCount: 134,
    completedCount: 290,
    cancellationRate: 0.02,
    pricePerVisit: 60.0,
    imageUrl: '',
    bio: 'Banho e tosa domiciliar com mais de 6 anos de experiência. Atende cães e gatos de todos os portes com paciência e carinho, sem estresse do transporte.',
    availableDays: ['Seg', 'Ter', 'Qui', 'Sex', 'Sab'],
    availableTimes: ['08:00', '09:00', '10:00', '13:00', '14:00', '15:00'],
    distanceKm: 1.8,
    isAvailable: true,
    neighborhoods: ['Botafogo', 'Flamengo', 'Laranjeiras', 'Humaitá', 'Catete'],
    services: [
      VetService(name: 'Banho – porte pequeno', description: 'Até 10 kg · banho, secagem e escovação', price: 60.0, unit: 'serviço'),
      VetService(name: 'Banho – porte médio', description: '10–25 kg · banho, secagem e escovação', price: 85.0, unit: 'serviço'),
      VetService(name: 'Banho – porte grande', description: 'Acima de 25 kg · banho, secagem e escovação', price: 120.0, unit: 'serviço'),
      VetService(name: 'Tosa higiênica – porte pequeno', description: 'Banho + tosa das patas, focinho e região higiênica', price: 80.0, unit: 'serviço'),
      VetService(name: 'Tosa higiênica – porte médio', description: 'Banho + tosa das patas, focinho e região higiênica', price: 110.0, unit: 'serviço'),
      VetService(name: 'Tosa completa – porte pequeno', description: 'Banho + tosa do corpo inteiro conforme padrão da raça', price: 120.0, unit: 'serviço'),
      VetService(name: 'Tosa completa – porte médio', description: 'Banho + tosa do corpo inteiro conforme padrão da raça', price: 160.0, unit: 'serviço'),
    ],
  ),
  const VetModel(
    id: '7',
    name: 'Dra. Priscila Vaz',
    crmv: 'CRMV-RJ 33120',
    specialty: 'Acupuntura',
    specialtyTags: ['Cães', 'Gatos', 'Dor crônica', 'Neurologia', 'Bem-estar'],
    rating: 4.9,
    reviewCount: 74,
    completedCount: 230,
    cancellationRate: 0.03,
    pricePerVisit: 170.0,
    imageUrl: '',
    bio: 'Especialista em acupuntura e medicina integrativa veterinária. Certificada pela IVAS (Associação Internacional de Acupuntura Veterinária). Indicada para animais com dor crônica, artrite, doenças neurológicas e ansiedade.',
    availableDays: ['Ter', 'Qui', 'Sab'],
    availableTimes: ['09:00', '10:00', '14:00', '15:00', '16:00'],
    distanceKm: 2.4,
    isAvailable: true,
    neighborhoods: ['Ipanema', 'Leblon', 'Gávea', 'Jardim Botânico'],
    services: [
      VetService(name: 'Sessão avulsa', description: 'Sessão individual de acupuntura (45–60 min)', price: 170.0, unit: 'sessão'),
      VetService(name: 'Pacote 5 sessões', description: '5 sessões com 10% de desconto', price: 765.0, unit: 'pacote', packageSessions: 5),
      VetService(name: 'Pacote 10 sessões', description: '10 sessões com 20% de desconto', price: 1360.0, unit: 'pacote', packageSessions: 10),
      VetService(name: 'Avaliação integrativa', description: 'Consulta inicial + elaboração do protocolo de tratamento', price: 130.0, unit: 'consulta'),
    ],
  ),
];
