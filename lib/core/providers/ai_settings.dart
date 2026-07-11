import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads AI settings from Firestore `settings/ai` document.
/// Admin panel saves API key, model, temperature, etc. here.
class AiSettingsProvider extends ChangeNotifier {
  String _apiKey = '';
  String _model = 'nvidia/llama-3.1-nemotron-70b-instruct';
  double _temperature = 0.72;
  int _maxTokens = 4096;
  double _topP = 0.90;
  String _promptProfile = 'Strict Clinical (Default)';
  bool _isLoading = false;
  String? _error;

  static const _kApiKey = 'nvidia_api_key';

  String get apiKey => _apiKey;
  String get model => _model;
  double get temperature => _temperature;
  int get maxTokens => _maxTokens;
  double get topP => _topP;
  String get promptProfile => _promptProfile;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConfigured => _apiKey.isNotEmpty;

  String get apiEndpoint => 'https://integrate.api.nvidia.com/v1/chat/completions';

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('ai').get();
      if (doc.exists) {
        final d = doc.data()!;
        _apiKey = d['apiKey']?.toString() ?? '';
        _model = d['model']?.toString() ?? 'nvidia/llama-3.1-nemotron-70b-instruct';
        _temperature = (d['temperature'] as num?)?.toDouble() ?? 0.72;
        _maxTokens = (d['maxTokens'] as num?)?.toInt() ?? 4096;
        _topP = (d['topP'] as num?)?.toDouble() ?? 0.90;
        _promptProfile = d['promptProfile']?.toString() ?? 'Strict Clinical (Default)';
      }

      // Fallback: try SharedPreferences if Firestore is empty
      if (_apiKey.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        _apiKey = prefs.getString(_kApiKey) ?? '';
      }
    } catch (e) {
      _error = 'Failed to load AI settings: $e';
      // Fallback to SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        _apiKey = prefs.getString(_kApiKey) ?? '';
      } catch (_) {}
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateApiKey(String key) async {
    _apiKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKey, _apiKey);
    notifyListeners();
  }

  Future<void> updateModel(String model) async {
    _model = model.trim();
    notifyListeners();
  }

  Future<void> updateTemperature(double temp) async {
    _temperature = temp;
    notifyListeners();
  }

  Future<void> updateMaxTokens(int tokens) async {
    _maxTokens = tokens;
    notifyListeners();
  }

  Future<void> updateTopP(double topP) async {
    _topP = topP;
    notifyListeners();
  }

  void forceRefresh() {
    notifyListeners();
  }
}
