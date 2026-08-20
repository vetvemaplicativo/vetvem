import 'package:get/get.dart';
import '../../data/models/prontuario_model.dart';

class ProntuarioController extends GetxController {
  // Keyed por petName — migrará para petId com Firebase
  final _registros = <String, List<RegistroProntuario>>{}.obs;

  List<RegistroProntuario> getRegistrosPet(String petName) {
    final list = _registros[petName] ?? [];
    list.sort((a, b) => b.data.compareTo(a.data));
    return list;
  }

  void addRegistro(RegistroProntuario r) {
    final list = List<RegistroProntuario>.from(_registros[r.petName] ?? []);
    list.add(r);
    _registros[r.petName] = list;
    _registros.refresh();
  }

  @override
  void onInit() {
    super.onInit();
    _seedMockData();
  }

  void _seedMockData() {
    final registros = [
      RegistroProntuario(
        id: 'r1',
        consultaId: 'c2',
        petName: 'Pitoco',
        vetId: '2',
        vetName: 'Dr. Carlos Melo',
        vetSpecialty: 'Dermatologia',
        data: DateTime(2026, 5, 28),
        tipoServico: 'Consulta',
        peso: 9.2,
        medicamentos: const [
          Medicamento(
            nome: 'Apoquel',
            dosagem: '5,4 mg',
            frequencia: '1x ao dia',
            duracao: '14 dias',
          ),
        ],
        observacoes:
            'Pet apresenta dermatite alérgica leve na região abdominal. '
            'Recomendado banho com shampoo hipoalergênico 2x por semana. '
            'Retorno em 30 dias para avaliação.',
      ),
      RegistroProntuario(
        id: 'r2',
        consultaId: 'c1',
        petName: 'Pitoco',
        vetId: '1',
        vetName: 'Dra. Ana Lima',
        vetSpecialty: 'Clínica Geral',
        data: DateTime(2026, 6, 10),
        tipoServico: 'Consulta clínica',
        peso: 9.5,
        vacinas: [
          Vacina(
            nome: 'V10',
            dataAplicacao: DateTime(2026, 6, 10),
            proximaDose: DateTime(2027, 6, 10),
          ),
          Vacina(
            nome: 'Antirrábica',
            dataAplicacao: DateTime(2026, 6, 10),
            proximaDose: DateTime(2027, 6, 10),
          ),
        ],
        observacoes:
            'Animal saudável, bem-nutrido e ativo. '
            'Vacinação anual realizada. '
            'Orientado sobre higiene dental e controle de ectoparasitas.',
      ),
      RegistroProntuario(
        id: 'r3',
        consultaId: 'c_mimi_1',
        petName: 'Mimi',
        vetId: '1',
        vetName: 'Dra. Ana Lima',
        vetSpecialty: 'Clínica Geral',
        data: DateTime(2026, 4, 5),
        tipoServico: 'Check-up anual',
        peso: 4.1,
        vacinas: [
          Vacina(
            nome: 'Tríplice felina',
            dataAplicacao: DateTime(2026, 4, 5),
            proximaDose: DateTime(2027, 4, 5),
          ),
        ],
        observacoes:
            'Gata em bom estado geral. Peso estável. '
            'Orientações sobre dieta e enriquecimento ambiental.',
      ),
    ];

    for (final r in registros) {
      final list = List<RegistroProntuario>.from(_registros[r.petName] ?? []);
      list.add(r);
      _registros[r.petName] = list;
    }
  }
}
