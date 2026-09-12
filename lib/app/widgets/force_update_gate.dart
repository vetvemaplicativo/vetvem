import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Envolve o app inteiro (via `builder` do GetMaterialApp). Se o build
/// instalado estiver abaixo do mínimo definido em `config/{configDocId}`
/// (Firestore), trava a tela inteira com um aviso não-dispensável até o
/// usuário atualizar. Usado pra forçar migração de versões com bugs sérios
/// (ex.: fluxo de pagamento antigo) em vez de depender do usuário atualizar
/// por conta própria — a Play Store/App Store não fazem isso sozinhas.
///
/// Documento esperado em `config/{configDocId}`:
///   minBuildAndroid: 17
///   minBuildIOS: 21
///   playStoreUrl: "https://play.google.com/store/apps/details?id=..."
///   appStoreUrl: "https://apps.apple.com/app/id..."
///   updateMessage: "texto customizado (opcional)"
///
/// Falha ao checar (offline, doc ausente, etc.) NUNCA bloqueia o app —
/// só bloqueia quando a checagem confirma positivamente que está desatualizado.
class ForceUpdateGate extends StatefulWidget {
  final Widget child;
  final String configDocId;
  const ForceUpdateGate({
    super.key,
    required this.child,
    required this.configDocId,
  });

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  Map<String, String>? _block;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc(widget.configDocId)
          .get();
      if (!doc.exists) return;
      final d = doc.data()!;

      final minBuild = (Platform.isIOS
              ? d['minBuildIOS']
              : d['minBuildAndroid']) as num?;
      if (minBuild == null || currentBuild >= minBuild.toInt()) return;

      if (!mounted) return;
      setState(() {
        _block = {
          'message': (d['updateMessage'] as String?)?.trim().isNotEmpty == true
              ? d['updateMessage'] as String
              : 'Uma atualização importante está disponível. '
                  'Atualize para continuar usando o app.',
          'url': (Platform.isIOS ? d['appStoreUrl'] : d['playStoreUrl'])
                  as String? ??
              '',
        };
      });
    } catch (_) {
      // Nunca bloqueia por falha de checagem (sem internet, doc ausente...).
    }
  }

  @override
  Widget build(BuildContext context) {
    final block = _block;
    if (block == null) return widget.child;

    return PopScope(
      canPop: false,
      child: Material(
        color: const Color(0xFF102A43),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update_rounded,
                    color: Colors.white, size: 72),
                const SizedBox(height: 24),
                const Text(
                  'Atualização necessária',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  block['message']!,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 15, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: block['url']!.isEmpty
                      ? null
                      : () => launchUrl(Uri.parse(block['url']!),
                          mode: LaunchMode.externalApplication),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF102A43),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Atualizar agora',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
