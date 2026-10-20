import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../theme/app_theme.dart';
import '../profile/profile_controller.dart';

const _amber = Color(0xFFF59E0B);
const _amberDark = Color(0xFFB45309);
const _respondUrl =
    'https://southamerica-east1-vetvem-18bf4.cloudfunctions.net/respondToProposal';

/// Responde às sugestões de horário do profissional (função respondToProposal).
/// choice: 0..2 = horário escolhido, 'none' = nenhum serve (estorno automático).
/// Retorna null se deu certo, ou a mensagem de erro.
Future<String?> respondToProposal(String appointmentId, Object choice) async {
  try {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return 'Faça login novamente.';
    final res = await http
        .post(
          Uri.parse(_respondUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'appointmentId': appointmentId, 'choice': choice}),
        )
        .timeout(const Duration(seconds: 25));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && body['ok'] == true) return null;
    return (body['error'] ?? 'Não foi possível responder. Tente novamente.').toString();
  } catch (_) {
    return 'Sem conexão. Verifique a internet e tente novamente.';
  }
}

/// Cartão "o profissional sugeriu outros horários": o tutor toca num horário
/// para confirmar a consulta, ou em "Nenhum serve" para ser estornado.
class ProposalCard extends StatefulWidget {
  final ConsultationHistory item;
  const ProposalCard({super.key, required this.item});

  @override
  State<ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends State<ProposalCard> {
  bool _busy = false;

  String get _deadline {
    final ms = widget.item.proposalDeadline;
    if (ms == null) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} às ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _answer(Object choice, String confirmText, String okTitle, String okMsg) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(confirmText),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Voltar')),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('Confirmar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final err = await respondToProposal(widget.item.id, choice);
    if (!mounted) return;
    setState(() => _busy = false);
    Get.snackbar(
      err == null ? okTitle : 'Não foi possível',
      err ?? okMsg,
      snackPosition: SnackPosition.TOP,
      backgroundColor: err == null ? const Color(0xFF22C55E) : AppColors.error,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _amber.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🗓️ ${item.vetName} sugeriu novos horários',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: _amberDark)),
          const SizedBox(height: 6),
          Text(
            'Você pediu ${item.date} às ${item.time}. Escolha uma opção'
            '${_deadline.isNotEmpty ? ' até $_deadline' : ''}. '
            'Se nenhuma servir, o valor é devolvido.',
            style: const TextStyle(fontSize: 12, height: 1.4, color: _amberDark),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < item.proposals.length; i++) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _answer(
                          i,
                          'Confirmar a consulta em ${item.proposals[i]['date']} às ${item.proposals[i]['time']}?',
                          'Consulta confirmada!',
                          'Horário confirmado: ${item.proposals[i]['date']} às ${item.proposals[i]['time']}.',
                        ),
                icon: const Icon(Icons.event_available_rounded, size: 20),
                label: Text(
                    '${item.proposals[i]['date']} às ${item.proposals[i]['time']}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          TextButton(
            onPressed: _busy
                ? null
                : () => _answer(
                      'none',
                      'Nenhum horário serve? O valor pago será devolvido.',
                      'Pedido encerrado',
                      'O valor será estornado automaticamente.',
                    ),
            child: const Text('Nenhum serve, quero o estorno',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Faixa no topo da tela inicial com os pedidos que aguardam a escolha do tutor.
class ProposalsBanner extends StatelessWidget {
  const ProposalsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = Get.find<ProfileController>();
    return Obx(() {
      final list = profile.recentConsultations.where((c) => c.awaitingProposal).toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(children: [for (final c in list) ProposalCard(key: ValueKey(c.id), item: c)]);
    });
  }
}

/// Orientações do profissional (ex.: jejum) para a consulta confirmada.
class InstructionsCard extends StatelessWidget {
  final String text;
  const InstructionsCard({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 Orientações do veterinário',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _amberDark)),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: _amberDark)),
        ],
      ),
    );
  }
}
