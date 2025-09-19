import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../i18n/app_localizations.dart';
import '../services/pdf_service.dart';
// import '../services/api_service.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final args = (ModalRoute.of(context)?.settings.arguments ?? {}) as Map;
    final String raw = (args['resultType'] ?? 'self_care') as String;
    final String backendRec = (args['recommendation'] ?? '') as String;
    final String aiAdvice = (args['aiAdvice'] ?? '') as String;
    final double? aiConfidence = args['aiConfidence'] is num ? (args['aiConfidence'] as num).toDouble() : null;
    final String triageSummary = (args['summary'] ?? '') as String;
    final String key = _normalizeResultKey(raw);
    final _ResultStyle style = _styleFor(key, loc);
    final String message = backendRec.isNotEmpty ? backendRec : style.message;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('triage_results')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Card(
                color: style.color.withOpacity(0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Icon(style.icon, size: 72, color: style.color),
                      const SizedBox(height: 16),
                      Text(
                        loc.t(key),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: style.color,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              if (aiAdvice.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology_alt_outlined, color: Color(0xFF1E88E5)),
                            const SizedBox(width: 8),
                            Text(loc.t('ai_advice'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          aiAdvice,
                          textAlign: TextAlign.start,
                          style: const TextStyle(fontSize: 16, color: Color(0xFF212121)),
                        ),
                        if (aiConfidence != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            '${loc.t('confidence')}: ${(aiConfidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (kIsWeb) {
                          // Open in new tab on web
                          final svc = PdfService();
                          await svc.openPdfInBrowser(ReferralSummary(
                            symptoms: triageSummary,
                            resultType: key.toUpperCase(),
                            recommendation: message,
                            aiAdvice: aiAdvice,
                            aiConfidence: aiConfidence,
                            createdAt: DateTime.now(),
                          ));
                        } else {
                          await _generatePdf(context,
                              symptoms: triageSummary,
                              resultType: key,
                              recommendation: message,
                              aiAdvice: aiAdvice,
                              aiConfidence: aiConfidence);
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(loc.t('save_pdf')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (kIsWeb) {
                          // Fallback to opening in new tab on web
                          final svc = PdfService();
                          await svc.openPdfInBrowser(ReferralSummary(
                            symptoms: triageSummary,
                            resultType: key.toUpperCase(),
                            recommendation: message,
                            aiAdvice: aiAdvice,
                            aiConfidence: aiConfidence,
                            createdAt: DateTime.now(),
                          ));
                        } else {
                          await _sharePdf(context,
                              symptoms: triageSummary,
                              resultType: key,
                              recommendation: message,
                              aiAdvice: aiAdvice,
                              aiConfidence: aiConfidence);
                        }
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: Text(loc.t('share_pdf')),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/clinics'),
                icon: const Icon(Icons.local_hospital_outlined),
                label: Text(loc.t('nearby_clinics')),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
              // Map moved to dedicated MapScreen with OpenStreetMap via flutter_map
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdf(
    BuildContext context, {
    required String symptoms,
    required String resultType,
    required String recommendation,
    required String aiAdvice,
    required double? aiConfidence,
  }) async {
    try {
      final svc = PdfService();
      final file = await svc.generateReferralPdf(ReferralSummary(
        symptoms: symptoms,
        resultType: resultType.toUpperCase(),
        recommendation: recommendation,
        aiAdvice: aiAdvice,
        aiConfidence: aiConfidence,
        createdAt: DateTime.now(),
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  Future<void> _sharePdf(
    BuildContext context, {
    required String symptoms,
    required String resultType,
    required String recommendation,
    required String aiAdvice,
    required double? aiConfidence,
  }) async {
    try {
      final svc = PdfService();
      final file = await svc.generateReferralPdf(ReferralSummary(
        symptoms: symptoms,
        resultType: resultType.toUpperCase(),
        recommendation: recommendation,
        aiAdvice: aiAdvice,
        aiConfidence: aiConfidence,
        createdAt: DateTime.now(),
      ));
      await svc.sharePdf(file);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    }
  }

  String _normalizeResultKey(String raw) {
    var v = raw.trim().toLowerCase();
    // unify separators
    v = v.replaceAll(RegExp(r'[\s\-]+'), '_');
    // handle common variants
    if (v.contains('emerg')) return 'emergency';
    if (v.contains('urgent')) return 'urgent';
    if (v.contains('self') && v.contains('care')) return 'self_care';
    if (v == 'self_care') return 'self_care';
    return 'self_care';
  }

  _ResultStyle _styleFor(String key, AppLocalizations loc) {
    switch (key) {
      case 'emergency':
        return _ResultStyle(
          color: Colors.red,
          icon: Icons.error_outline,
          message: loc.t('emergency_message'),
        );
      case 'urgent':
        return _ResultStyle(
          color: Colors.orange,
          icon: Icons.priority_high,
          message: loc.t('urgent_message'),
        );
      default:
        return _ResultStyle(
          color: Colors.green,
          icon: Icons.self_improvement,
          message: loc.t('self_care_message'),
        );
    }
  }
}

class _ResultStyle {
  final Color color;
  final IconData icon;
  final String message;
  const _ResultStyle({required this.color, required this.icon, required this.message});
}
