/// Validação de CPF pelos dígitos verificadores (aceita com ou sem máscara).
bool isValidCpf(String? input) {
  final d = (input ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(d)) return false; // 111.111.111-11 etc.
  int digit(int len) {
    var sum = 0;
    for (var i = 0; i < len; i++) {
      sum += int.parse(d[i]) * (len + 1 - i);
    }
    final r = (sum * 10) % 11;
    return r == 10 ? 0 : r;
  }

  return digit(9) == int.parse(d[9]) && digit(10) == int.parse(d[10]);
}
