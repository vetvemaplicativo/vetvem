import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Dados públicos do profissional (vitrine): foto e CRMV.
class VetPublic {
  final ImageProvider? photo;
  final String crmv;
  const VetPublic(this.photo, this.crmv);
}

final Map<String, Future<VetPublic>> _vetPublicCache = {};

/// Busca foto e CRMV em professionals_public/{vetId} (com cache). Sem vetId ou sem
/// dados, devolve vazio — a tela mostra o ícone padrão.
Future<VetPublic> vetPublicOf(String vetId) {
  if (vetId.isEmpty) return Future.value(const VetPublic(null, ''));
  return _vetPublicCache.putIfAbsent(vetId, () async {
    try {
      final d = (await FirebaseFirestore.instance.collection('professionals_public').doc(vetId).get()).data();
      final b64 = (d?['photoBase64'] ?? '').toString();
      final url = (d?['photoUrl'] ?? '').toString();
      ImageProvider? photo;
      if (b64.isNotEmpty) {
        photo = MemoryImage(base64Decode(b64.split(',').last));
      } else if (url.isNotEmpty) {
        photo = NetworkImage(url);
      }
      return VetPublic(photo, (d?['crmv'] ?? '').toString().trim());
    } catch (_) {
      return const VetPublic(null, '');
    }
  });
}

/// Foto redonda do profissional (ícone padrão enquanto carrega ou se não houver).
class VetPhotoAvatar extends StatelessWidget {
  final String vetId;
  final double size;
  const VetPhotoAvatar({super.key, required this.vetId, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VetPublic>(
      future: vetPublicOf(vetId),
      builder: (_, snap) {
        final image = snap.data?.photo;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            image: image != null ? DecorationImage(image: image, fit: BoxFit.cover) : null,
          ),
          child: image == null ? Icon(Icons.person, color: AppColors.primary, size: size * 0.5) : null,
        );
      },
    );
  }
}
