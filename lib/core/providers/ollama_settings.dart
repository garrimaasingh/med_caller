import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Manages Ollama server connection settings (IP, port, model)
/// Persisted via SharedPreferences.
class OllamaSettings extends ChangeNotifier {
  static const _kIp    = 'ollama_ip';
  static const _kPort  = 'ollama_port';
  static const _kModel = 'ollama_model';
  static const _kLang  = 'ollama_lang';

  String _ip    = '192.168.0.104';
  int    _port  = 11434;
  String _model = 'gemma3:4b';
  String _lang  = 'English'; // English or Hinglish

  bool    _isConnected    = false;
  bool    _isTesting      = false;
  String? _connectionError;

  // ── Getters ──────────────────────────────────────────────────────────────────
  String  get ip              => _ip;
  int     get port            => _port;
  String  get model           => _model;
  String  get language        => _lang;
  bool    get isConnected     => _isConnected;
  bool    get isTesting       => _isTesting;
  String? get connectionError => _connectionError;

  String get baseUrl      => 'http://$_ip:$_port';
  String get generateUrl  => '$baseUrl/api/generate';
  String get tagsUrl      => '$baseUrl/api/tags';

  // ── Load from SharedPreferences ───────────────────────────────────────────────
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _ip    = prefs.getString(_kIp)    ?? '192.168.0.104';
    _port  = prefs.getInt(_kPort)     ?? 11434;
    _model = prefs.getString(_kModel) ?? 'gemma3:4b';
    _lang  = prefs.getString(_kLang)  ?? 'English';

    
    notifyListeners();
  }

  // ── Setters ───────────────────────────────────────────────────────────────────
  Future<void> setIp(String ip) async {
    _ip = ip.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIp, _ip);
    _isConnected = false;
    notifyListeners();
  }

  Future<void> setPort(int port) async {
    _port = port;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPort, port);
    _isConnected = false;
    notifyListeners();
  }

  Future<void> setModel(String model) async {
    _model = model.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModel, _model);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _lang = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLang, lang);
    notifyListeners();
  }

  // ── Test connection ────────────────────────────────────────────────────────────
  Future<bool> testConnection() async {
    _isTesting = true;
    _connectionError = null;
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse(tagsUrl))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List?) ?? [];
        final modelNames = models.map((m) => m['name'].toString()).toList();
        
        // Try exact match or match with tags
        String? actualName;
        if (modelNames.contains(_model)) {
          actualName = _model;
        } else {
          // Find first model that starts with our name (e.g. gemma:7b matching gemma:7b-instruct)
          actualName = modelNames.where((n) => n.startsWith('$_model:') || n == _model.split(':')[0]).firstOrNull;
        }

        _isConnected = actualName != null;
        if (_isConnected) {
          if (_model != actualName) {
            _model = actualName!;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kModel, _model);
          }
        } else {
          _connectionError = 'Model "$_model" not found. Available: ${modelNames.take(3).join(", ")}';
        }
      } else {
        _isConnected = false;
        _connectionError = 'Server returned ${response.statusCode}';
      }
    } catch (e) {
      _isConnected = false;
      _connectionError = 'Cannot reach $_ip:$_port. Tip: Use 10.0.2.2 if on Emulator.';
    }

    _isTesting = false;
    notifyListeners();
    return _isConnected;
  }
}
