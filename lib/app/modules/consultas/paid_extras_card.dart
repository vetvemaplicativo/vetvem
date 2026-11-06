import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Adicionais já PAGOS da consulta (curativo, medicação, vacina...). Só leitura: o tutor não
/// aprova nada no app, ele combina com o profissional na hora e paga o QR PIX. Aparece depois
/// do pagamento. A consulta filtra por status == paid porque as regras só liberam esses.
class PaidExtrasCard extends StatelessWidget {
  final String appointmentId;
  final double bottomGap; // espaço abaixo do cartão (só quando ele aparece)
  const PaidExtrasCard({super.key, required this.appointmentId, this.bottomGap = 0});

  static String _brl(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

  @override
  Widget build(BuildContext context) {
    if (appointmentId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .collection('extras')
          .where('status', isEqualTo: 'paid')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? const [];
        if (docs.isEmpty) return const SizedBox.shrink();
        final blocks = docs.map((d) => d.data()).toList();
        final grand = blocks.fold<double>(0, (s, b) => s + ((b['total'] as num?)?.toDouble() ?? 0));
        return Padding(
          padding: EdgeInsets.only(top: 12, bottom: bottomGap),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_task_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Adicionais da consulta',
                          style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                    ),
                    Text('Pago · ${_brl(grand)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF16A34A))),
                  ],
                ),
                const SizedBox(height: 8),
                for (final b in blocks)
                  for (final it in (b['items'] as List?)?.whereType<Map>() ?? const <Map>[])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text((it['name'] ?? '').toString(),
                                style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
                          ),
                          Text(_brl((it['value'] as num?) ?? 0),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
