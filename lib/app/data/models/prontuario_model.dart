class Vacina {
  final String nome;
  final DateTime dataAplicacao;
  final DateTime? proximaDose;

  const Vacina({
    required this.nome,
    required this.dataAplicacao,
    this.proximaDose,
  });
}

class Medicamento {
  final String nome;
  final String dosagem;
  final String frequencia;
  final String duracao;

  const Medicamento({
    required this.nome,
    required this.dosagem,
    required this.frequencia,
    required this.duracao,
  });
}

class RegistroProntuario {
  final String id;
  final String consultaId;
  final String petName;
  final String vetId;
  final String vetName;
  final String vetSpecialty;
  final DateTime data;
  final String tipoServico;
  final double? peso;
  final List<Vacina> vacinas;
  final List<Medicamento> medicamentos;
  final String observacoes;

  const RegistroProntuario({
    required this.id,
    required this.consultaId,
    required this.petName,
    required this.vetId,
    required this.vetName,
    required this.vetSpecialty,
    required this.data,
    required this.tipoServico,
    this.peso,
    this.vacinas = const [],
    this.medicamentos = const [],
    this.observacoes = '',
  });
}
