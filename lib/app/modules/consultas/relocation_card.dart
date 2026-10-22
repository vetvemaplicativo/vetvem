import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../profile/profile_controller.dart';
import 'proposal_card.dart';

const _cfBase = 'https://southamerica-east1-vetvem-18bf4.cloudfunctions.net';

/// POST autenticado nas funções de realocação. Retorna null se deu certo, ou a mensagem de erro.
Future<String?> _post(String fn, Map<String, dynamic> data) async {
  try {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) return 'Faça login novamente.';
    final res = await http
        .post(
          Uri.parse('$_cfBase/$fn'),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 25));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && body['ok'] == true) return null;
    return (body['error'] ?? 'Não foi possível concluir. Tente novamente.').toString();
  } catch (_) {
    return 'Sem conexão. Verifique a internet e tente novamente.';
  }
}

Future<String?> chooseRelocation(String appointmentId, String vetId) =>
    _post('chooseRelocation', {'appointmentId': appointmentId, 'vetId': vetId});

Future<String?> cancelRelocation(String appointmentId) =>
    _post('cancelRelocation', {'appointmentId': appointmentId});

String _brl(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

String _hhmm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

/// Foto do profissional (vitrine pública), com cache simples.
final Map<String, Future<ImageProvider?>> _photoCache = {};
Future<ImageProvider?> _photoOf(String vetId) => _photoCache.putIfAbsent(vetId, () async {
      try {
        final d = (await FirebaseFirestore.instance.collection('professionals_public').doc(vetId).get()).data();
        final b64 = (d?['photoBase64'] ?? '').toString();
        final url = (d?['photoUrl'] ?? '').toString();
        if (b64.isNotEmpty) return MemoryImage(base64Decode(b64.split(',').last));
        if (url.isNotEmpty) return NetworkImage(url);
      } catch (_) {}
      return null;
    });

class _Avatar extends StatelessWidget {
  final String vetId;
  const _Avatar({required this.vetId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ImageProvider?>(
      future: _photoOf(vetId),
      builder: (_, snap) {
        final image = snap.data;
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            image: image != null ? DecorationImage(image: image, fit: BoxFit.cover) : null,
          ),
          child: image == null ? const Icon(Icons.person, color: AppColors.primary, size: 28) : null,
        );
      },
    );
  }
}

/// "O profissional não pôde atender": o tutor escolhe um dos profissionais que atendem
/// no mesmo dia e horário, ou cancela e pede o estorno. [onDone] roda após uma escolha/cancelamento.
class RelocationCard extends StatefulWidget {
  final ConsultationHistory item;
  final VoidCallback? onDone;
  const RelocationCard({super.key, required this.item, this.onDone});

  @override
  State<RelocationCard> createState() => _RelocationCardState();
}

class _RelocationCardState extends State<RelocationCard> {
  bool _busy = false;

  void _toast(bool ok, String title, String msg) => Get.snackbar(
        title,
        msg,
        snackPosition: SnackPosition.TOP,
        backgroundColor: ok ? const Color(0xFF22C55E) : AppColors.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );

  Future<void> _choose(Map<String, dynamic> o) async {
    final item = widget.item;
    final price = (o['price'] as num?)?.toDouble() ?? 0;
    final r = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmSheet(
        icon: Icons.person_search_rounded,
        color: AppColors.primary,
        title: 'Escolher este profissional?',
        highlight: '${o['vetName']}',
        message:
            '${o['serviceName']} · ${_brl(price)}\n${item.date} às ${item.time}\n\nSe o valor da consulta for menor que o que você pagou, a diferença será devolvida. O profissional ainda precisa confirmar o atendimento.',
        confirmLabel: 'Confirmar profissional',
        extraLabel: 'Cancelar consulta e devolver meu pagamento',
      ),
    );
    if (r == 'extra') return _cancel();
    if (r != true) return;
    setState(() => _busy = true);
    final err = await chooseRelocation(item.id, '${o['vetId']}');
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      _toast(true, 'Pedido enviado!', '${o['vetName']} vai confirmar a sua consulta.');
      widget.onDone?.call();
    } else {
      _toast(false, 'Não foi possível', err);
    }
  }

  Future<void> _cancel() async {
    final item = widget.item;
    final r = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ConfirmSheet(
        icon: Icons.undo_rounded,
        color: AppColors.error,
        title: 'Cancelar e devolver o pagamento?',
        highlight: item.value.isNotEmpty ? 'Estorno de R\$ ${item.value}' : 'Estorno total',
        message: 'A consulta será cancelada e o valor pago devolvido automaticamente.',
        confirmLabel: 'Cancelar e devolver o pagamento',
      ),
    );
    if (r != true) return;
    setState(() => _busy = true);
    final err = await cancelRelocation(item.id);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      _toast(true, 'Consulta cancelada', 'O valor será estornado automaticamente.');
      widget.onDone?.call();
    } else {
      _toast(false, 'Não foi possível', err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final who = item.originalVetName.isNotEmpty ? item.originalVetName : 'O profissional que você escolheu';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/images/troca.png', width: 34, height: 34),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Escolha outro profissional',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('$who não pôde atender a sua consulta.',
              style: const TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                const Text('Estes profissionais podem atender no mesmo dia e horário',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textMedium)),
                const SizedBox(height: 8),
                Text(item.date,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                Text('às ${item.time}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final o in item.relocationOptions) ...[
            _OptionTile(option: o, busy: _busy, onChoose: () => _choose(o)),
            const SizedBox(height: 12),
          ],
          const Text(
            'Se o valor da consulta for menor, a diferença será devolvida a você.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textMedium),
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Text('Nenhum profissional serve?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _cancel,
              icon: const Icon(Icons.undo_rounded, size: 20),
              label: const Text('Cancelar consulta e devolver meu pagamento',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final Map<String, dynamic> option;
  final bool busy;
  final VoidCallback onChoose;
  const _OptionTile({required this.option, required this.busy, required this.onChoose});

  @override
  Widget build(BuildContext context) {
    final price = (option['price'] as num?)?.toDouble() ?? 0;
    final crmv = (option['crmv'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(vetId: '${option['vetId']}'),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${option['vetName']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    if (crmv.isNotEmpty)
                      Text('CRMV $crmv',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMedium)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text('${option['serviceName']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                ),
                const SizedBox(width: 8),
                Text(_brl(price),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: busy ? null : onChoose,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Escolher este profissional',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faixa no topo da tela inicial: pedidos que aguardam a escolha de outro profissional.
class RelocationBanner extends StatelessWidget {
  const RelocationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = Get.find<ProfileController>();
    return Obx(() {
      final list = profile.recentConsultations.where((c) => c.awaitingRelocation).toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        children: [
          for (final c in list)
            GestureDetector(
              onTap: () => Get.toNamed(Routes.consultaDetail, arguments: c),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Image.asset('assets/images/troca.png', width: 34, height: 34),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Escolha outro profissional',
                              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            'Sua consulta de ${c.date} às ${c.time} precisa de outro profissional'
                            '${c.relocationDeadline != null ? ' · escolha até ${_hhmm(c.relocationDeadline!)}' : ''}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}
