import 'package:flutter/material.dart';
import '../i18n/app_localizations.dart';
import '../services/api_service.dart';

class TriageScreen extends StatefulWidget {
  const TriageScreen({super.key});

  @override
  State<TriageScreen> createState() => _TriageScreenState();
}

class _TriageScreenState extends State<TriageScreen> {
  int _currentIndex = 0;
  int _score = 0;
  final List<int> _selectedPerQuestion = [];
  final ApiService _api = ApiService();
  bool _submitting = false;

  final List<_Question> _questions = [
    _Question(
      text: 'Are you experiencing severe chest pain or shortness of breath?',
      options: [
        _Option('Yes, severe', 3),
        _Option('Mild discomfort', 1),
        _Option('No', 0),
      ],
    ),
    _Question(
      text: 'Do you have a high fever (above 39°C) lasting more than 2 days?',
      options: [
        _Option('Yes', 2),
        _Option('No', 0),
      ],
    ),
    _Question(
      text: 'Any recent injury with bleeding or suspected fracture?',
      options: [
        _Option('Yes', 3),
        _Option('Not sure', 1),
        _Option('No', 0),
      ],
    ),
    _Question(
      text: 'Rate your pain level',
      options: [
        _Option('Severe', 2),
        _Option('Moderate', 1),
        _Option('Mild/None', 0),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final bool finished = _currentIndex >= _questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('symptom_triage')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Color(0xFFE8F5E9)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: finished ? _buildFinish(context) : _buildQuestion(context),
        ),
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final q = _questions[_currentIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / _questions.length,
            color: const Color(0xFF1E88E5),
            backgroundColor: const Color(0xFFBBDEFB),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${loc.t('question')} ${_currentIndex + 1} ${loc.t('of')} ${_questions.length}',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        const SizedBox(height: 12),
        _questionText(context, q),
        const SizedBox(height: 24),
        ...List.generate(q.options.length, (i) {
          final opt = q.options[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton(
              onPressed: () => _selectOption(i, opt.score),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(14),
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _optionText(context, q, i),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFinish(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final resultType = _computeResultType(_score);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(
          resultType == 'emergency'
              ? Icons.error_outline
              : resultType == 'urgent'
                  ? Icons.priority_high
                  : Icons.self_improvement,
          size: 88,
          color: resultType == 'emergency'
              ? Colors.red
              : resultType == 'urgent'
                  ? Color(0xFFFF9800)
                  : Color(0xFF43A047),
        ),
        const SizedBox(height: 16),
        Text(
          loc.t('triage_complete'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E88E5)),
        ),
        const SizedBox(height: 12),
        Text(
          '${loc.t('result_label')}: ${loc.t(resultType)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _submitting ? null : () async {
            setState(() => _submitting = true);
            final summary = _buildSymptomSummary();
            try {
              final res = await _api.triage(symptom: summary);
              // Also call AI triage advice for multilingual + richer guidance
              Map<String, dynamic>? aiRes;
              try {
                aiRes = await _api.aiTriageAdvice(symptom: summary);
              } catch (_) {
                aiRes = null;
              }
              if (!mounted) return;
              Navigator.pushNamed(
                context,
                '/results',
                arguments: {
                  'resultType': res['status'] ?? resultType,
                  'recommendation': res['recommendation'] ?? '',
                  'aiAdvice': aiRes != null ? (aiRes['advice'] as String? ?? '') : '',
                  'aiConfidence': aiRes != null ? (aiRes['confidence'] as double?) : null,
                  'summary': summary,
                },
              );
            } catch (e) {
              if (!mounted) return;
              // Navigate with local fallback if backend is unreachable
              Navigator.pushNamed(
                context,
                '/results',
                arguments: {
                  'resultType': resultType,
                  'recommendation': '',
                  'aiAdvice': '',
                  'aiConfidence': null,
                  'summary': summary,
                },
              );
              // Optionally inform the user
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Showing offline results. Server unreachable: $e')),
              );
            } finally {
              if (mounted) setState(() => _submitting = false);
            }
          },
          icon: const Icon(Icons.assessment_outlined),
          label: Text(_submitting ? 'Loading...' : loc.t('see_results')),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
        ),
      ],
    );
  }

  void _selectOption(int optionIndex, int score) {
    _score += score;
    _selectedPerQuestion.add(optionIndex);
    setState(() {
      _currentIndex += 1;
    });
  }

  String _computeResultType(int score) {
    // Simple rule-based thresholds
    if (score >= 6) return 'emergency';
    if (score >= 3) return 'urgent';
    return 'self_care';
  }

  String _buildSymptomSummary() {
    // Create a simple sentence summarizing selected answers for backend triage
    final parts = <String>[];
    for (var i = 0; i < _selectedPerQuestion.length && i < _questions.length; i++) {
      final q = _questions[i];
      final idx = _selectedPerQuestion[i];
      if (idx >= 0 && idx < q.options.length) {
        parts.add('${q.text} => ${q.options[idx].label}');
      }
    }
    if (parts.isEmpty) {
      return 'General symptoms';
    }
    return parts.join('. ');
  }
}

class _Question {
  final String text;
  final List<_Option> options;
  const _Question({required this.text, required this.options});
}

class _Option {
  final String label;
  final int score;
  const _Option(this.label, this.score);
}

Widget _questionText(BuildContext context, _Question q) {
  final loc = AppLocalizations.of(context);
  String key = '';
  if (q.text.startsWith('Are you experiencing')) key = 'q1';
  else if (q.text.startsWith('Do you have a high fever')) key = 'q2';
  else if (q.text.startsWith('Any recent injury')) key = 'q3';
  else if (q.text.startsWith('Rate your pain level')) key = 'q4';

  return Text(
    key.isNotEmpty ? loc.t(key) : q.text,
    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
  );
}

Widget _optionText(BuildContext context, _Question q, int index) {
  final loc = AppLocalizations.of(context);
  String keyPrefix = '';
  if (q.text.startsWith('Are you experiencing')) keyPrefix = 'q1';
  else if (q.text.startsWith('Do you have a high fever')) keyPrefix = 'q2';
  else if (q.text.startsWith('Any recent injury')) keyPrefix = 'q3';
  else if (q.text.startsWith('Rate your pain level')) keyPrefix = 'q4';

  final optionKey = '${keyPrefix}_opt${index + 1}';
  final label = (keyPrefix.isNotEmpty) ? loc.t(optionKey) : q.options[index].label;
  return Text(label, style: const TextStyle(fontSize: 16));
}
