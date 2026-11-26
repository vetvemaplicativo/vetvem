import 'package:flutter/material.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../profile/profile_controller.dart';

/// Status da consulta em texto + cores (redesign 2.0). Só apresentação:
/// as regras de status/pagamento continuam no modelo e no servidor.
class ConsultaStatus {
  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;
  const ConsultaStatus(this.label, this.bg, this.fg, this.icon);

  static const _amberBg = Color(0xFFFFF1C7);
  static const _amberFg = Color(0xFF6B4E00);
  static const _redBg = Color(0xFFFBE3E1);
  static const _redFg = Color(0xFF8C1D18);

  static ConsultaStatus of(ConsultationHistory item) {
    switch (item.status) {
      case 'completed':
        return const ConsultaStatus('Concluída', Vv2.successBg, Vv2.successFg,
            Icons.check_circle_outline_rounded);
      case 'confirmed':
        return const ConsultaStatus('Confirmada', Vv2.successBg, Vv2.successFg,
            Icons.check_circle_outline_rounded);
      case 'cancelled':
        return const ConsultaStatus(
            'Cancelada', _redBg, _redFg, Icons.cancel_outlined);
      case 'rejected':
        return ConsultaStatus(
            item.cancelledByTutor
                ? 'Cancelada'
                : item.tutorTimedOut
                    ? 'Encerrada'
                    : 'Recusada',
            _redBg,
            _redFg,
            Icons.cancel_outlined);
      case 'pending_confirmation':
        return ConsultaStatus(
            item.awaitingPayment
                ? 'Aguardando pagamento'
                : item.paymentInReview
                    ? 'Pagamento em análise'
                    : 'Aguardando confirmação',
            _amberBg,
            _amberFg,
            Icons.schedule_rounded);
      case 'pending_payment':
        return const ConsultaStatus('Aguardando pagamento', _amberBg, _amberFg,
            Icons.schedule_rounded);
      default:
        return const ConsultaStatus(
            'Agendada', _amberBg, _amberFg, Icons.schedule_rounded);
    }
  }
}

/// Pílula de status com ícone + texto (não depende só da cor).
class ConsultaStatusPill extends StatelessWidget {
  final ConsultaStatus status;
  const ConsultaStatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.bg,
        borderRadius: BorderRadius.circular(Vv2.rPill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(status.icon, size: 15, color: status.fg),
        const SizedBox(width: 5),
        Flexible(
          child: Text(status.label,
              style: Vv2.t(13, 18, 700, color: status.fg)),
        ),
      ]),
    );
  }
}
