import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/ollama_settings.dart';
import '../models/ai_history.dart';

// ── Result model (shared across all AI services) ──────────────────────────────

class AISummaryResult {
  final List<String> quickSummary;
  final AIHistory history;
  final String suggestedStatus;   
  final int improvementPercent;
  final String timelineEntry;

  const AISummaryResult({
    required this.quickSummary,
    required this.history,
    required this.suggestedStatus,
    required this.improvementPercent,
    required this.timelineEntry,
  });
}

class AIException implements Exception {
  final String title;
  final String details;
  AIException(this.title, this.details);
  @override
  String toString() => 'AIException: $title — $details';
}

// ── Ollama Service ────────────────────────────────────────────────────────────

class OllamaService {
  final OllamaSettings settings;

  OllamaService(this.settings);

  static const Duration _timeout = Duration(seconds: 120);

  // Structured prompt — works well with small models like gemma:2b
  static String _buildPrompt(String input, String _) {
    return '''
You are an AI Medical History Assistant designed for doctors and clinics.
Your task is to listen to patient conversations and generate a COMPLETE STRUCTURED PATIENT HISTORY similar to how homeopathic doctors maintain detailed case histories.

Your response must always be in VALID JSON format only.
No markdown, no explanation outside JSON.

Analyze the conversation deeply and extract:
1. Basic Information (name, age, gender, occupation)
2. Medical History (current symptoms, past diseases, chronic illnesses, allergies, ongoing medicines, surgeries, blood pressure, diabetes, thyroid, asthma, digestion issues)
3. Lifestyle Information (sleep quality, eating habits, water intake, smoking, alcohol, exercise, stress level)
4. Mental & Emotional State (anxiety, anger, depression, overthinking, emotional sensitivity, fear, mood patterns)
5. Family Medical History (diabetes, heart disease, BP, asthma, cancer, thyroid)
6. Physical Tendencies (sensitivity to cold/heat, sweating, weakness, body pain, headaches, fatigue)
7. Timeline Information: Generate important medical events in chronological order.
8. Doctor Quick Summary: Generate a short 2-4 line summary.
9. Risk Level: Classify (low, medium, high)
10. Follow-up Requirement: true or false

JSON FORMAT:
{
  "basic_info": { "name": null, "age": null, "gender": null, "occupation": null },
  "medical_history": {
    "current_symptoms": [], "past_diseases": [], "chronic_illnesses": [], "allergies": [], 
    "ongoing_medicines": [], "surgeries": [], "blood_pressure": null, "diabetes": null, 
    "thyroid": null, "asthma": null, "digestion_issues": []
  },
  "lifestyle": { "sleep_quality": null, "eating_habits": null, "water_intake": null, "smoking": null, "alcohol": null, "exercise": null, "stress_level": null },
  "mental_emotional_state": { "anxiety": null, "anger": null, "depression": null, "overthinking": null, "emotional_sensitivity": null, "fear": null, "mood_patterns": [] },
  "family_history": { "diabetes": null, "heart_disease": null, "blood_pressure": null, "asthma": null, "cancer": null, "thyroid": null },
  "physical_tendencies": { "cold_or_heat_sensitivity": null, "sweating": null, "weakness": null, "body_pain": null, "headaches": null, "fatigue": null },
  "timeline": [],
  "doctor_quick_summary": "",
  "risk_level": "low",
  "follow_up_required": false
}

Text to analyze:
"""
$input
"""
''';
  }

  // ── Core API call ────────────────────────────────────────────────────────────

  Future<AISummaryResult> _generate(String input) async {
    if (input.trim().isEmpty) {
      throw AIException('Empty input', 'Please provide text to analyze.');
    }

    final prompt = _buildPrompt(input, settings.language);

    try {
      final response = await http
          .post(
            Uri.parse(settings.generateUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': settings.model,
              'prompt': prompt,
              'stream': false,
              'format': 'json',
              'options': {
                'temperature': 0.2,
                'num_predict': 1536,
              },
            }),
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw AIException(
          'Ollama Error ${response.statusCode}',
          response.body.length > 200 ? response.body.substring(0, 200) : response.body,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawText = data['response'] as String? ?? '';
      if (rawText.trim().isEmpty) {
        throw AIException('Empty response', 'Ollama returned an empty response. Try again.');
      }

      return _parseResponse(rawText);
    } on AIException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw AIException(
          'Request timed out',
          'Ollama took too long. Check that the model is loaded: run "ollama run ${settings.model}"',
        );
      }
      throw AIException('Connection failed', 'Cannot reach Ollama at ${settings.baseUrl}. Is it running?');
    }
  }

  // ── Parse structured text response ───────────────────────────────────────────

  AISummaryResult _parseResponse(String raw) {
    try {
      // Clean JSON if model wrapped it in markdown code blocks
      String cleaned = raw.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned.replaceAll(RegExp(r'^```(json)?'), '');
        cleaned = cleaned.replaceAll(RegExp(r'```$'), '');
        cleaned = cleaned.trim();
      }
      
      final data = jsonDecode(cleaned) as Map<String, dynamic>;
      
      final history = AIHistory.fromJson(data);
      
      List<String> quickSummary = [history.doctorQuickSummary];
      if (quickSummary.first.isEmpty) {
        quickSummary = (history.medicalHistory.currentSymptoms.take(3).toList());
      }

      return AISummaryResult(
        quickSummary: quickSummary.isEmpty ? ['No clinical summary generated'] : quickSummary,
        history: history,
        suggestedStatus: 'stable', 
        improvementPercent: 0,
        timelineEntry: history.timeline.isNotEmpty ? history.timeline.last : history.doctorQuickSummary,
      );
    } catch (e) {
      throw AIException('Parsing error', 'Failed to parse AI output. Try generating again.');
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────────

  Future<AISummaryResult> generateMedicalSummary(String transcript) =>
      _generate(transcript);

  Future<AISummaryResult> generatePatientSummary({
    required String patientName,
    required String healthIssue,
    required String symptoms,
    required String medication,
    required String notes,
    required String sinceWhen,
    required int age,
    required String gender,
  }) {
    final input = '''
Patient: $patientName | Age: $age | Gender: $gender
Health Issue: $healthIssue | Since: $sinceWhen
Symptoms: $symptoms
Medication: $medication
Doctor Notes: $notes
''';
    return _generate(input);
  }

  Future<AISummaryResult> generateTimelineUpdate(String consultationNotes) =>
      _generate(consultationNotes);
}
