import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import '../../theme/vv2/vv2_tokens.dart';
import '../../widgets/auth_widgets.dart';
import '../consultas/proposal_card.dart';
import '../consultas/relocation_card.dart';
import '../profile/profile_controller.dart';

const _relocBg = Color(0xFFFBE3D9);
const _relocFg = Color(0xFF7A2D10);
const _propBg = Color(0xFFFFF1CC);
const _propFg = Color(0xFF6B4A06);

String _two(int n) => n.toString().padLeft(2, '0');
String _hhmm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_two(d.hour)}:${_two(d.minute)}';
}

String _ddmmHhmm(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_two(d.day)}/${_two(d.month)} às ${_two(d.hour)}:${_two(d.minute)}';
}

/// "26/11/2026" -> "26/11" (o ano fica implícito nos horários sugeridos).
String _shortDate(String d) =>
    RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(d) ? d.substring(0, 5) : d;

/// Avisos com prazo no topo da Home: realocação (urgente) primeiro, depois os
/// horários sugeridos. Prazos e valores vêm do servidor; as ações chamam as
/// mesmas funções do detalhe da consulta.
class HomeAlerts extends StatelessWidget {
  const HomeAlerts({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = Get.find<ProfileController>();
    return Obx(() {
      final reloc =
          profile.recentConsultations.where((c) => c.awaitingRelocation).toList();
      final props =
          profile.recentConsultations.where((c) => c.awaitingProposal).toList();
      if (reloc.isEmpty && props.isEmpty) return const SizedBox.shrink();
      final compact = reloc.isNotEmpty && props.isNotEmpty;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in reloc)
            _RelocationAlert(key: ValueKey('r${c.id}'), item: c, compact: compact),
          for (final c in props)
            _ProposalAlert(key: ValueKey('p${c.id}'), item: c),
        ],
      );
    });
  }
}

class _AlertHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String deadline;
  final String detail;
  final Color bg, fg;
  const _AlertHeader({
    required this.icon,
    required this.title,
    required this.deadline,
    required this.detail,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(Vv2.rOverlay)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: Vv2.t(17, 24, 700))),
            ],
          ),
          if (deadline.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(deadline, style: Vv2.t(15, 22, 700, color: fg)),
          ],
          const SizedBox(height: 4),
          Text(detail, style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
        ],
      ),
    );
  }
}

class _RelocationAlert extends StatefulWidget {
  final ConsultationHistory item;
  final bool compact;
  const _RelocationAlert({super.key, required this.item, required this.compact});

  @override
  State<_RelocationAlert> createState() => _RelocationAlertState();
}

class _RelocationAlertState extends State<_RelocationAlert> {
  bool _busy = false;

  void _open() => Get.toNamed(Routes.consultaDetail, arguments: widget.item);

  Future<void> _cancel() async {
    final item = widget.item;
    final r = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmSheet(
        icon: Icons.undo_rounded,
        color: AppColors.error,
        title: 'Cancelar e devolver o pagamento?',
        highlight:
            item.value.isNotEmpty ? 'Estorno de R\$ ${item.value}' : 'Estorno total',
        message: 'A consulta será cancelada e o valor pago devolvido automaticamente.',
        confirmLabel: 'Cancelar e devolver o pagamento',
      ),
    );
    if (r != true) return;
    setState(() => _busy = true);
    final err = await cancelRelocation(item.id);
    if (!mounted) return;
    setState(() => _busy = false);
    Get.snackbar(
      err == null ? 'Consulta cancelada' : 'Não foi possível',
      err ?? 'O valor será estornado automaticamente.',
      snackPosition: SnackPosition.TOP,
      backgroundColor: err == null ? const Color(0xFF22C55E) : AppColors.error,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.item;
    final header = _AlertHeader(
      icon: Icons.swap_vert_rounded,
      title: 'Escolha outro profissional',
      deadline: c.relocationDeadline != null
          ? 'Escolha até ${_hhmm(c.relocationDeadline!)}'
          : '',
      detail: 'Consulta: ${c.date} às ${c.time}',
      bg: _relocBg,
      fg: _relocFg,
    );
    final cta = VvPillButton(
      label: 'Escolher outro profissional',
      arrow: true,
      onTap: _busy ? null : _open,
    );
    if (widget.compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, const SizedBox(height: 10), cta],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(Vv2.rOverlay)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    c.originalVetName.isNotEmpty
                        ? '${c.originalVetName} não pôde atender.'
                        : 'Seu profissional não pôde atender.',
                    style: Vv2.t(17, 24, 700)),
                const SizedBox(height: 4),
                Text('Selecione outro profissional para a consulta.',
                    style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
                const SizedBox(height: 14),
                cta,
                AuthTextLink('Cancelar consulta e devolver meu pagamento',
                    onTap: _busy ? () {} : _cancel),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('O valor total será estornado.',
              textAlign: TextAlign.center,
              style: Vv2.t(13, 18, 400, color: Vv2.textSecondary)),
        ],
      ),
    );
  }
}

class _ProposalAlert extends StatefulWidget {
  final ConsultationHistory item;
  const _ProposalAlert({super.key, required this.item});

  @override
  State<_ProposalAlert> createState() => _ProposalAlertState();
}

class _ProposalAlertState extends State<_ProposalAlert> {
  bool _busy = false;

  Future<void> _answer(
    Object choice, {
    required IconData icon,
    required Color color,
    required String title,
    required String highlight,
    required String message,
    required String confirmLabel,
    required String okTitle,
    required String okMsg,
  }) async {
    final ok = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ConfirmSheet(
        icon: icon,
        color: color,
        title: title,
        highlight: highlight,
        message: message,
        confirmLabel: confirmLabel,
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final err = await respondToProposal(widget.item.id, choice);
    if (!mounted) return;
    setState(() => _busy = false);
    final relocated = err == null && choice == 'none' && proposalRelocated;
    Get.snackbar(
      err == null
          ? (relocated ? 'Escolha outro profissional' : okTitle)
          : 'Não foi possível',
      err ?? (relocated ? 'Veja quem atende no mesmo dia e horário.' : okMsg),
      snackPosition: SnackPosition.TOP,
      backgroundColor: err == null ? const Color(0xFF22C55E) : AppColors.error,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  void _pick(int i) {
    final item = widget.item;
    final p = item.proposals[i];
    _answer(
      i,
      icon: Icons.event_available_rounded,
      color: const Color(0xFF22C55E),
      title: 'Confirmar este horário?',
      highlight: '${p['date']} às ${p['time']}',
      message:
          'Consulta com ${item.vetName}. Ao confirmar, o horário fica reservado para você.',
      confirmLabel: 'Confirmar consulta',
      okTitle: 'Consulta confirmada!',
      okMsg: 'Horário confirmado: ${p['date']} às ${p['time']}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.item;
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    final stack = scale > 1.15;
    final chips = [
      for (var i = 0; i < c.proposals.length; i++)
        _TimeChip(
          label:
              '${_shortDate('${c.proposals[i]['date']}')} às ${c.proposals[i]['time']}',
          onTap: _busy ? null : () => _pick(i),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AlertHeader(
            icon: Icons.calendar_month_outlined,
            title: '${c.vetName} sugeriu novos horários',
            deadline: c.proposalDeadline != null
                ? 'Escolha até ${_ddmmHhmm(c.proposalDeadline!)}'
                : '',
            detail: 'Você pediu ${c.date} às ${c.time}.',
            bg: _propBg,
            fg: _propFg,
          ),
          const SizedBox(height: 10),
          if (stack)
            for (final ch in chips) ...[ch, const SizedBox(height: 8)]
          else
            LayoutBuilder(builder: (context, box) {
              final w = (box.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final ch in chips) SizedBox(width: w, child: ch)],
              );
            }),
          const SizedBox(height: 10),
          Text('Se nenhuma servir, o valor é devolvido.',
              style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => _answer(
                        'none',
                        icon: Icons.groups_rounded,
                        color: AppColors.primary,
                        title: 'Quer ver outros profissionais?',
                        highlight: 'Mesmo dia e horário',
                        message:
                            'Vamos procurar outros profissionais para o mesmo dia e horário que você pediu. Se não houver nenhum, o pedido é encerrado e o valor devolvido.',
                        confirmLabel: 'Ver outros profissionais',
                        okTitle: 'Pedido encerrado',
                        okMsg: 'O valor será estornado automaticamente.',
                      ),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, Vv2.tapMin)),
              child: Text('Quero ver outros profissionais',
                  style: Vv2.t(15, 20, 700, color: Vv2.primary)),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => _answer(
                        'cancel',
                        icon: Icons.undo_rounded,
                        color: AppColors.error,
                        title: 'Cancelar a consulta?',
                        highlight: 'Estorno total',
                        message:
                            'A consulta será cancelada e o valor total devolvido automaticamente.',
                        confirmLabel: 'Cancelar a consulta',
                        okTitle: 'Consulta cancelada',
                        okMsg: 'O valor será estornado automaticamente.',
                      ),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(48, Vv2.tapMin)),
              child: Text('Prefiro cancelar a consulta',
                  style: Vv2.t(15, 20, 700, color: Vv2.primary)),
            ),
          ),
          Text('O valor total será estornado.',
              style: Vv2.t(13, 18, 400, color: Vv2.textSecondary)),
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _TimeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Escolher $label',
      excludeSemantics: true,
      child: Material(
        color: _propBg,
        borderRadius: BorderRadius.circular(Vv2.rPill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Vv2.rPill),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_month_outlined,
                      size: 18, color: _propFg),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: Vv2.t(15, 20, 700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
