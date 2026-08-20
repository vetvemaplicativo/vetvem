import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../theme/app_theme.dart';
import '../profile/profile_controller.dart';

class ProntuarioView extends StatelessWidget {
  const ProntuarioView({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>;
    final item = args['item'] as ConsultationHistory;
    final p = item.prontuario ?? {};

    final peso = p['peso']?.toString() ?? '';
    final vacinas = List<Map<String, dynamic>>.from(p['vacinas'] ?? []);
    final medicamentos =
        List<Map<String, dynamic>>.from(p['medicamentos'] ?? []);
    final observacoes = p['observacoes']?.toString() ?? '';
    final editedAt = p['editedAt'];
    final complementos =
        List<Map<String, dynamic>>.from(p['complementos'] ?? []);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Header
          Material(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      onPressed: () => Get.back(),
                    ),
                    const Text('🐾', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Prontuário de ${item.petName}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins')),
                          Text('${item.vetName} · ${item.date}',
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontFamily: 'Poppins')),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Baixar / Compartilhar PDF',
                      icon: const Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.white, size: 22),
                      onPressed: () => _openPdfPreview(
                          context, item, peso, vacinas, medicamentos,
                          observacoes, complementos),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Conteúdo
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Banner VetVem
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Registro oficial VetVem · ${item.serviceName}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary),
                        ),
                      ),
                      if (editedAt != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Atualizado',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706))),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Peso
                if (peso.isNotEmpty) ...[
                  _Section(
                    icon: Icons.monitor_weight_outlined,
                    color: AppColors.textMedium,
                    title: 'Peso registrado',
                    child: Text('$peso kg',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Vacinas
                if (vacinas.isNotEmpty) ...[
                  _Section(
                    icon: Icons.vaccines_outlined,
                    color: const Color(0xFF22C55E),
                    title: 'Vacinas aplicadas',
                    child: Column(
                      children: vacinas.map((v) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 14, color: Color(0xFF22C55E)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(v['nome'] ?? '',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textDark)),
                                    if ((v['proximaDose'] ?? '').isNotEmpty)
                                      Text(
                                          'Próxima dose: ${v['proximaDose']}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMedium)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Medicamentos
                if (medicamentos.isNotEmpty) ...[
                  _Section(
                    icon: Icons.medication_outlined,
                    color: const Color(0xFF3B82F6),
                    title: 'Medicamentos prescritos',
                    child: Column(
                      children: medicamentos.map((m) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6)
                                .withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['nome'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textDark)),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if ((m['dosagem'] ?? '').isNotEmpty)
                                    m['dosagem'],
                                  if ((m['frequencia'] ?? '').isNotEmpty)
                                    m['frequencia'],
                                  if ((m['duracao'] ?? '').isNotEmpty)
                                    m['duracao'],
                                ].join(' · '),
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMedium),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Observações
                if (observacoes.isNotEmpty) ...[
                  _Section(
                    icon: Icons.notes_rounded,
                    color: const Color(0xFFF59E0B),
                    title: 'Observações clínicas',
                    child: Text(observacoes,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textDark,
                            height: 1.6)),
                  ),
                  const SizedBox(height: 16),
                ],

                // Complementos
                if (complementos.isNotEmpty) ...[
                  _Section(
                    icon: Icons.add_comment_rounded,
                    color: const Color(0xFF8B5CF6),
                    title: 'Complementos (${complementos.length})',
                    child: Column(
                      children: complementos.map((c) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6)
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF8B5CF6)
                                    .withValues(alpha: 0.2)),
                          ),
                          child: Text(c['texto']?.toString() ?? '',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textDark,
                                  height: 1.5)),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Rodapé
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline,
                          size: 14, color: AppColors.textLight),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Registro oficial vinculado à consulta na plataforma VetVem.',
                          style: TextStyle(
                              fontSize: 11, color: AppColors.textLight),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Botão PDF
                OutlinedButton.icon(
                  onPressed: () => _openPdfPreview(
                      context, item, peso, vacinas, medicamentos,
                      observacoes, complementos),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Ver / Baixar PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPdfPreview(
    BuildContext context,
    ConsultationHistory item,
    String peso,
    List<Map<String, dynamic>> vacinas,
    List<Map<String, dynamic>> medicamentos,
    String observacoes,
    List<Map<String, dynamic>> complementos,
  ) async {
    try {
      await Printing.layoutPdf(
        name: 'prontuario_${item.petName}_${item.date}',
        onLayout: (_) => _buildPdf(
            item, peso, vacinas, medicamentos, observacoes, complementos),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar PDF: $e')),
        );
      }
    }
  }

  Future<Uint8List> _buildPdf(
    ConsultationHistory item,
    String peso,
    List<Map<String, dynamic>> vacinas,
    List<Map<String, dynamic>> medicamentos,
    String observacoes,
    List<Map<String, dynamic>> complementos,
  ) async {
    final orange = PdfColor.fromHex('#FF6B2B');
    final dark = PdfColor.fromHex('#111827');
    final medium = PdfColor.fromHex('#6B7280');
    final light = PdfColor.fromHex('#9CA3AF');
    final border = PdfColor.fromHex('#E5E7EB');
    final bgLight = PdfColor.fromHex('#F9FAFB');

    final pdf = pw.Document(
      title: 'Prontuario Veterinario - ${item.petName}',
      author: item.vetName,
    );

    // cabeçalho de seção reutilizável
    pw.Widget secHeader(String title) => pw.Container(
          margin: const pw.EdgeInsets.only(top: 16, bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: orange)),
              pw.SizedBox(height: 3),
              pw.Container(height: 0.8, color: orange),
            ],
          ),
        );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(45, 40, 45, 40),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'VetVem - Veterinário a domicílio | Documento ${item.id.toUpperCase().substring(0, 8)} | Pag ${ctx.pageNumber}/${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: light),
          ),
        ),
        build: (ctx) => [
          // ── CABEÇALHO ────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(0, 0, 0, 14),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: orange, width: 2))),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Logo + nome
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('VetVem',
                          style: pw.TextStyle(
                              fontSize: 26,
                              fontWeight: pw.FontWeight.bold,
                              color: orange)),
                      pw.Text('Veterinário a domicílio',
                          style:
                              pw.TextStyle(fontSize: 10, color: medium)),
                    ],
                  ),
                ),
                // Tipo de documento + data
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: orange,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        medicamentos.isNotEmpty
                            ? 'PRONTUÁRIO / RECEITUÁRIO'
                            : 'PRONTUÁRIO CLÍNICO',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Data: ${item.date}',
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: dark)),
                    if (item.time.isNotEmpty)
                      pw.Text('Horário: ${item.time}',
                          style: pw.TextStyle(fontSize: 10, color: medium)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),

          // ── VETERINÁRIO ───────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: bgLight,
              border: pw.Border.all(color: border),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('VETERINÁRIO RESPONSÁVEL',
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: medium,
                            )),
                    pw.SizedBox(height: 4),
                    pw.Text(item.vetName,
                        style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: dark)),
                    if (item.specialty.isNotEmpty)
                      pw.Text(item.specialty,
                          style:
                              pw.TextStyle(fontSize: 10, color: medium)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                      item.vetCrmv.isNotEmpty
                          ? item.vetCrmv
                          : 'CRMV: não informado',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: item.vetCrmv.isNotEmpty ? dark : light)),
                ],
              ),
            ]),
          ),
          pw.SizedBox(height: 10),

          // ── PACIENTE ──────────────────────────────────────────────
          pw.Row(children: [
            pw.Expanded(
              flex: 3,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: border),
                  borderRadius: const pw.BorderRadius.only(
                    topLeft: pw.Radius.circular(4),
                    bottomLeft: pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PACIENTE',
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: medium,
                            )),
                    pw.SizedBox(height: 6),
                    _pdfRow('Nome', item.petName),
                    pw.SizedBox(height: 3),
                    _pdfRow('Serviço', item.serviceName),
                  ],
                ),
              ),
            ),
            pw.SizedBox(width: 1),
            pw.Expanded(
              flex: 2,
              child: pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: bgLight,
                  border: pw.Border.all(color: border),
                  borderRadius: const pw.BorderRadius.only(
                    topRight: pw.Radius.circular(4),
                    bottomRight: pw.Radius.circular(4),
                  ),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DADOS CLÍNICOS',
                        style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: medium,
                            )),
                    pw.SizedBox(height: 6),
                    if (peso.isNotEmpty)
                      _pdfRow('Peso', '$peso kg'),
                  ],
                ),
              ),
            ),
          ]),

          // ── MEDICAMENTOS / Rx ─────────────────────────────────────
          if (medicamentos.isNotEmpty) ...[
            secHeader('Rx - MEDICAMENTOS PRESCRITOS'),
            ...medicamentos.asMap().entries.map((e) {
              final i = e.key + 1;
              final m = e.value;
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 8),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: border),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$i.  ${m['nome'] ?? ''}',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: dark)),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      [
                        if ((m['dosagem'] ?? '').isNotEmpty)
                          'Dosagem: ${m['dosagem']}',
                        if ((m['frequencia'] ?? '').isNotEmpty)
                          m['frequencia'],
                        if ((m['duracao'] ?? '').isNotEmpty)
                          'por ${m['duracao']}',
                      ].join('  |  '),
                      style: pw.TextStyle(fontSize: 10, color: medium),
                    ),
                  ],
                ),
              );
            }),
          ],

          // ── VACINAS ───────────────────────────────────────────────
          if (vacinas.isNotEmpty) ...[
            secHeader('VACINAS ADMINISTRADAS'),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: border),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: vacinas.map((v) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4),
                      child: pw.Row(children: [
                        pw.Text('[x]  ',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#22C55E'))),
                        pw.Text(v['nome'] ?? '',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: dark)),
                        if ((v['proximaDose'] ?? '').isNotEmpty) ...[
                          pw.Text('  -  Proxima dose: ',
                              style: pw.TextStyle(
                                  fontSize: 9, color: medium)),
                          pw.Text(v['proximaDose'],
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: dark)),
                        ],
                      ]),
                    )).toList(),
              ),
            ),
          ],

          // ── OBSERVAÇÕES ───────────────────────────────────────────
          if (observacoes.isNotEmpty) ...[
            secHeader('OBSERVAÇÕES CLÍNICAS'),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: border),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(observacoes,
                  style: pw.TextStyle(
                      fontSize: 10, color: dark, lineSpacing: 4)),
            ),
          ],

          // ── COMPLEMENTOS ──────────────────────────────────────────
          if (complementos.isNotEmpty) ...[
            secHeader('COMPLEMENTOS / ADENDOS'),
            ...complementos.asMap().entries.map((e) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: PdfColor.fromHex('#C4B5FD')),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Complemento ${e.key + 1}',
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('#7C3AED'),
                              )),
                      pw.SizedBox(height: 4),
                      pw.Text(e.value['texto']?.toString() ?? '',
                          style: pw.TextStyle(
                              fontSize: 10, color: dark, lineSpacing: 3)),
                    ],
                  ),
                )),
          ],

          // ── ASSINATURA ────────────────────────────────────────────
          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 220,
                    height: 0.5,
                    color: dark,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(item.vetName,
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: dark)),
                  pw.Text(
                      item.vetCrmv.isNotEmpty
                          ? item.vetCrmv
                          : 'CRMV: não informado',
                      style: pw.TextStyle(fontSize: 9, color: medium)),
                ],
              ),
              pw.Container(
                width: 80,
                height: 80,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: border),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Center(
                  child: pw.Text('CARIMBO',
                      style: pw.TextStyle(fontSize: 9, color: light)),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Divider(color: border),
          pw.SizedBox(height: 6),
          pw.Text(
            'Documento: VV-${item.id.toUpperCase().substring(0, 12)}  |  Emitido em ${item.date} pela plataforma VetVem',
            style: pw.TextStyle(fontSize: 8, color: light),
          ),
        ],
      ),
    );

    return Uint8List.fromList(await pdf.save());
  }

  pw.Widget _pdfRow(String label, String value) => pw.Row(
        children: [
          pw.Text('$label: ',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#6B7280'))),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10, color: PdfColor.fromHex('#111827'))),
        ],
      );
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;
  const _Section(
      {required this.icon,
      required this.color,
      required this.title,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
