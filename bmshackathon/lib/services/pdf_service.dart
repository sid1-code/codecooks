import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ReferralSummary {
  final String symptoms;
  final String resultType; // EMERGENCY/URGENT/SELF-CARE
  final String recommendation;
  final String aiAdvice;
  final double? aiConfidence; // 0..1
  final DateTime createdAt;

  ReferralSummary({
    required this.symptoms,
    required this.resultType,
    required this.recommendation,
    required this.aiAdvice,
    required this.createdAt,
    this.aiConfidence,
  });
}

class PdfService {
  pw.Document _buildDoc(ReferralSummary s) {
    final doc = pw.Document();
    final df = DateFormat('yyyy-MM-dd HH:mm');
    final confidenceStr = s.aiConfidence != null
        ? '${(s.aiConfidence! * 100).toStringAsFixed(0)}%'
        : 'N/A';

    final primary = const PdfColor.fromInt(0xFF1E88E5);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text('Health Assistant Referral Summary',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: primary,
                    )),
                pw.SizedBox(height: 8),
                pw.Text('Generated: ${df.format(s.createdAt)}'),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Text('Symptoms',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: primary)),
                pw.SizedBox(height: 6),
                pw.Text(s.symptoms),
                pw.SizedBox(height: 12),
                pw.Text('Risk Level',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: primary)),
                pw.SizedBox(height: 6),
                pw.Text(s.resultType),
                pw.SizedBox(height: 12),
                pw.Text('Recommendation',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: primary)),
                pw.SizedBox(height: 6),
                pw.Text(s.recommendation.isEmpty
                    ? 'No additional recommendation.'
                    : s.recommendation),
                pw.SizedBox(height: 12),
                pw.Text('AI Advice',
                    style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: primary)),
                pw.SizedBox(height: 6),
                pw.Text(s.aiAdvice.isEmpty ? 'No AI advice.' : s.aiAdvice),
                pw.SizedBox(height: 12),
                pw.Text('Confidence: $confidenceStr'),
                pw.Spacer(),
                pw.Divider(),
                pw.Text(
                  'This is not a diagnosis. Please seek professional care if symptoms persist or worsen.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: const PdfColor.fromInt(0xFF555555),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    return doc;
  }

  Future<Uint8List> generateReferralPdfBytes(ReferralSummary s) async {
    final doc = _buildDoc(s);
    return doc.save();
  }

  Future<File> generateReferralPdf(ReferralSummary s) async {
    final bytes = await generateReferralPdfBytes(s);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/referral_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> sharePdf(File file) async {
    await Share.shareXFiles([XFile(file.path)], text: 'Referral Summary');
  }

  Future<void> openPdfInBrowser(ReferralSummary s) async {
    final bytes = await generateReferralPdfBytes(s);
    final b64 = base64Encode(bytes);
    final dataUrl = 'data:application/pdf;base64,$b64';
    await launchUrlString(dataUrl, mode: LaunchMode.externalApplication);
  }
}
