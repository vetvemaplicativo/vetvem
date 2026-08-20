class BrazilianState {
  final String sigla;
  final String nome;

  const BrazilianState({required this.sigla, required this.nome});
}

/// As 27 unidades federativas do Brasil (26 estados + DF), em ordem alfabética.
const brazilianStates = [
  BrazilianState(sigla: 'AC', nome: 'Acre'),
  BrazilianState(sigla: 'AL', nome: 'Alagoas'),
  BrazilianState(sigla: 'AP', nome: 'Amapá'),
  BrazilianState(sigla: 'AM', nome: 'Amazonas'),
  BrazilianState(sigla: 'BA', nome: 'Bahia'),
  BrazilianState(sigla: 'CE', nome: 'Ceará'),
  BrazilianState(sigla: 'DF', nome: 'Distrito Federal'),
  BrazilianState(sigla: 'ES', nome: 'Espírito Santo'),
  BrazilianState(sigla: 'GO', nome: 'Goiás'),
  BrazilianState(sigla: 'MA', nome: 'Maranhão'),
  BrazilianState(sigla: 'MT', nome: 'Mato Grosso'),
  BrazilianState(sigla: 'MS', nome: 'Mato Grosso do Sul'),
  BrazilianState(sigla: 'MG', nome: 'Minas Gerais'),
  BrazilianState(sigla: 'PA', nome: 'Pará'),
  BrazilianState(sigla: 'PB', nome: 'Paraíba'),
  BrazilianState(sigla: 'PR', nome: 'Paraná'),
  BrazilianState(sigla: 'PE', nome: 'Pernambuco'),
  BrazilianState(sigla: 'PI', nome: 'Piauí'),
  BrazilianState(sigla: 'RJ', nome: 'Rio de Janeiro'),
  BrazilianState(sigla: 'RN', nome: 'Rio Grande do Norte'),
  BrazilianState(sigla: 'RS', nome: 'Rio Grande do Sul'),
  BrazilianState(sigla: 'RO', nome: 'Rondônia'),
  BrazilianState(sigla: 'RR', nome: 'Roraima'),
  BrazilianState(sigla: 'SC', nome: 'Santa Catarina'),
  BrazilianState(sigla: 'SP', nome: 'São Paulo'),
  BrazilianState(sigla: 'SE', nome: 'Sergipe'),
  BrazilianState(sigla: 'TO', nome: 'Tocantins'),
];
