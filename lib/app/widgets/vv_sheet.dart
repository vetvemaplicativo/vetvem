import 'package:flutter/material.dart';

import '../theme/vv2/vv2_tokens.dart';
import 'auth_widgets.dart';

/// Folha padrão do redesign 2.0 (telas complementares): puxador laranja,
/// título à esquerda, subtítulo opcional, conteúdo rolável e ações empilhadas.
class VvSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  const VvSheet({
    super.key,
    required this.title,
    this.subtitle,
    this.children = const [],
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      constraints: BoxConstraints(maxHeight: mq.size.height * 0.92),
      decoration: const BoxDecoration(
        color: Vv2.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(Vv2.rOverlay)),
      ),
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              Vv2.gutter, 10, Vv2.gutter, Vv2.gutter),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Vv2.brand,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Semantics(
                header: true,
                child: Text(title, style: Vv2.t(22, 28, 700)),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(subtitle!,
                    style: Vv2.t(14, 20, 400, color: Vv2.textSecondary)),
              ],
              const SizedBox(height: 16),
              ..._gap(children, 8),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                ..._gap(actions, 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static List<Widget> _gap(List<Widget> ws, double g) => [
        for (var i = 0; i < ws.length; i++) ...[
          if (i > 0) SizedBox(height: g),
          ws[i],
        ]
      ];
}

/// Abre uma [VvSheet] com fundo transparente (os cantos ficam visíveis).
Future<T?> showVvSheet<T>(BuildContext context, Widget Function(BuildContext) builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: builder,
    );

/// Cartão creme de informação/opção: rótulo em negrito e valor abaixo.
class VvInfoCard extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? labelColor;
  const VvInfoCard({
    super.key,
    required this.label,
    this.value,
    this.leading,
    this.trailing,
    this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(Vv2.rControl);
    return Material(
      color: Vv2Pastel.cream,
      shape: RoundedRectangleBorder(
        borderRadius: r,
        side: const BorderSide(color: Vv2.pressedSurface),
      ),
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Vv2.tapMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: Vv2.t(14, 20, 700,
                              color: labelColor ?? Vv2.text)),
                      if (value != null && value!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(value!,
                            style: Vv2.t(12, 18, 400,
                                color: Vv2.textSecondary)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirmação padrão em folha. Retorna true só quando a ação é confirmada.
Future<bool> vvConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  String cancelLabel = 'Voltar',
  bool destructive = false,
  List<Widget> details = const [],
}) async {
  final r = await showVvSheet<bool>(
    context,
    (ctx) => VvSheet(
      title: title,
      subtitle: message,
      actions: [
        VvPillButton(
          label: confirmLabel,
          kind: destructive ? VvPillKind.danger : VvPillKind.primary,
          onTap: () => Navigator.of(ctx).pop(true),
        ),
        VvPillButton(
          label: cancelLabel,
          kind: VvPillKind.outlined,
          onTap: () => Navigator.of(ctx).pop(false),
        ),
      ],
      children: details,
    ),
  );
  return r == true;
}
