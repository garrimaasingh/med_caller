import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/ai_settings.dart';

/// NVIDIA NIM AI Service for MedCaller
/// Uses admin-configured API key and model from Firestore.
class AIService {
  final AiSettingsProvider settings;

  AIService(this.settings);

  static const Duration _timeout = Duration(seconds: 60);

  static const String _systemPrompt = '''
You are an AI medical documentation assistant for homeopathy doctors.

Extract only medically relevant information from doctor-patient conversations or patient notes.

Identify:
- symptoms
- medicines prescribed or ongoing
- patient condition (improving / stable / no improvement)
- lifestyle issues (stress, diet, sleep, exercise)
- sleep problems
- emotional state (anxiety, depression, irritability)
- follow-up duration
- treatment updates and changes
- improvement status with percentage if possible

Ignore:
- greetings
- casual conversation
- unrelated discussion

Always respond in this exact JSON format:
{
  "quickSummary": ["bullet1", "bullet2", "bullet3", "bullet4", "bullet5"],
  "detailedNotes": {
    "symptoms": "...",
    "medicines": "...",
    "condition": "...",
    "lifestyle": "...",
    "sleepIssues": "...",
    "emotionalState": "...",
    "treatmentUpdate": "...",
    "followUp": "..."
  },
  "suggestedStatus": "improving",
  "improvementPercent": 60,
  "timelineEntry": "Short one-line entry for timeline e.g. Headache improving. Continue Natrum Mur 200."
}

suggestedStatus must be exactly one of: improving, recovering, no_improvement
improvementPercent is a number 0-100.
Do not invent information not present in the input.
''';

  // ── Core API call ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _callAPI(String userContent) async {
    if (!settings.isConfigured) {
      throw AIException(
        'API not configured',
        'Set NVIDIA API key in Admin Panel → AI Settings first.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse(settings.apiEndpoint),
            headers: {
              'Authorization': 'Bearer ${settings.apiKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': settings.model,
              'messages': [
                {'role': 'system', 'content': _systemPrompt},
                {'role': 'user', 'content': userContent},
              ],
              'temperature': settings.temperature,
              'max_tokens': settings.maxTokens,
              'top_p': settings.topP,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        final cleaned = content
            .replaceAll(RegExp(r'```json\s*'), '')
            .replaceAll(RegExp(r'```\s*'), '')
            .trim();
        return jsonDecode(cleaned) as Map<String, dynamic>;
      }

      if (response.statusCode == 401) {
        throw AIException(
          'Invalid API Key',
          'The NVIDIA API key is invalid. Update it in Admin Panel → AI Settings.',
        );
      }

      if (response.statusCode == 429) {
        throw AIException(
          'Rate Limited',
          'Too many requests. Wait a moment and try again.',
        );
      }

      throw AIException('API Error ${response.statusCode}', response.body);
    } on AIException {
      rethrow;
    } catch (e) {
      throw AIException('Connection failed', 'Cannot reach NVIDIA API. Check internet.');
    }
  }

  // ── Public methods ─────────────────────────────────────────────────────────

  Future<AISummaryResult> generateMedicalSummary(String transcript) async {
    if (transcript.trim().isEmpty) {
      throw AIException('Empty transcript', 'Please provide a transcript to analyze.');
    }
    final prompt = 'Here is the doctor-patient conversation transcript:\n\n$transcript';
    final json = await _callAPI(prompt);
    return AISummaryResult.fromJson(json);
  }

  Future<AISummaryResult> generatePatientSummary({
    required String patientName,
    required String healthIssue,
    required String symptoms,
    required String medication,
    required String notes,
    required String sinceWhen,
    required int age,
    required String gender,
  }) async {
    final prompt = '''
Patient Profile:
Name: $patientName
Age: $age | Gender: $gender
Health Issue: $healthIssue
Since: $sinceWhen
Symptoms: $symptoms
Current Medication: $medication
Doctor Notes: $notes

Generate a comprehensive AI medical summary for this patient profile.
''';
    final json = await _callAPI(prompt);
    return AISummaryResult.fromJson(json);
  }

  Future<AISummaryResult> generateTimelineUpdate(String consultationNotes) async {
    final prompt = 'Generate a timeline update from this consultation note:\n\n$consultationNotes';
    final json = await _callAPI(prompt);
    return AISummaryResult.fromJson(json);
  }

  Future<List<String>> generateQuickBullets({
    required String healthIssue,
    required String medication,
    required String notes,
    required String status,
    required String lastVisit,
  }) async {
    final prompt = '''
Patient quick card data:
Issue: $healthIssue
Medicine: $medication
Notes: $notes
Status: $status
Last Visit: $lastVisit

Generate exactly 4 brief bullet points for a quick patient summary card.
''';
    final json = await _callAPI(prompt);
    final result = AISummaryResult.fromJson(json);
    return result.quickSummary;
  }
}

// ── Result model ─────────────────────────────────────────────────────────────

class AISummaryResult {
  final List<String> quickSummary;
  final Map<String, String> detailedNotes;
  final String suggestedStatus;
  final int improvementPercent;
  final String timelineEntry;

  const AISummaryResult({
    required this.quickSummary,
    required this.detailedNotes,
    required this.suggestedStatus,
    required this.improvementPercent,
    required this.timelineEntry,
  });

  factory AISummaryResult.fromJson(Map<String, dynamic> json) {
    final qs =
        (json['quickSummary'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final dn = (json['detailedNotes'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        ) ??
        {};
    return AISummaryResult(
      quickSummary: qs,
      detailedNotes: Map<String, String>.from(dn),
      suggestedStatus: json['suggestedStatus']?.toString() ?? 'improving',
      improvementPercent: (json['improvementPercent'] as num?)?.toInt() ?? 0,
      timelineEntry: json['timelineEntry']?.toString() ?? '',
    );
  }

  String get symptomsSummary => detailedNotes['symptoms'] ?? '';
  String get medicinesSummary => detailedNotes['medicines'] ?? '';
  String get conditionSummary => detailedNotes['condition'] ?? '';
  String get treatmentUpdate => detailedNotes['treatmentUpdate'] ?? '';
  String get followUp => detailedNotes['followUp'] ?? '';
  String get lifestyle => detailedNotes['lifestyle'] ?? '';
  String get sleepIssues => detailedNotes['sleepIssues'] ?? '';
  String get emotionalState => detailedNotes['emotionalState'] ?? '';
}

// ── Exception ─────────────────────────────────────────────────────────────────

class AIException implements Exception {
  final String title;
  final String details;
  AIException(this.title, this.details);

  @override
  String toString() => 'AIException: $title — $details';
}
