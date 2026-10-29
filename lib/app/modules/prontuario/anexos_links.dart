import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';

void _snack(BuildContext context, String msg) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Abre um anexo do prontuário (imagem ou PDF) no visualizador do celular. O Storage só libera
/// o arquivo ao tutor da consulta (e ao veterinário que o enviou).
Future<void> openAnexo(BuildContext context, Map<String, dynamic> item) async {
  try {
    final url = await FirebaseStorage.instance.ref(item['path'] as String).getDownloadURL();
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('sem app para abrir');
  } catch (_) {
    if (context.mounted) _snack(context, 'Não foi possível abrir o anexo agora.');
  }
}

/// Baixa o anexo para o celular e abre o menu de compartilhar do sistema (salvar na galeria ou
/// nos arquivos, enviar por WhatsApp ou e-mail).
Future<void> shareAnexo(BuildContext context, Map<String, dynamic> item) async {
  try {
    final url = await FirebaseStorage.instance.ref(item['path'] as String).getDownloadURL();
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('download ${res.statusCode}');
    final dir = await getTemporaryDirectory();
    final name = (item['name']?.toString() ?? 'anexo').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(res.bodyBytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: item['type']?.toString())],
      text: 'Anexo do prontuário - VetVem',
    ));
  } catch (_) {
    if (context.mounted) _snack(context, 'Não foi possível baixar o anexo agora.');
  }
}

/// Lista de anexos (somente leitura): tocar abre; o botão de baixar salva ou compartilha.
class AnexosLinks extends StatelessWidget {
  final List<dynamic> items;
  const AnexosLinks({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final list = items.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final it in list)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => openAnexo(context, it),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Icon(
                          (it['type'] as String? ?? '') == 'application/pdf'
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(it['name']?.toString() ?? 'arquivo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download_rounded, size: 22, color: AppColors.primary),
                  tooltip: 'Baixar ou compartilhar',
                  onPressed: () => shareAnexo(context, it),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
