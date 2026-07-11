import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/firebase_service.dart';

class PatientProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  List<Patient> _patients = [];
  bool _isLoading = false;
  String _searchQuery = '';

  bool get isLoading => _isLoading;
  List<Patient> get allPatients => _patients;

  List<Patient> get filteredPatients {
    if (_searchQuery.isEmpty) return _patients;
    return _patients
        .where((p) =>
            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            p.phoneNumber.contains(_searchQuery))
        .toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> fetchPatients() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_firebaseService.currentUser != null) {
        _patients = await _firebaseService.getDoctorsPatients();
      } else {
        _patients = [];
      }
    } catch (e) {
      debugPrint("Error fetching patients: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addPatient(Patient patient) async {
    try {
      await _firebaseService.addPatient(patient);
      _patients.add(patient);
      notifyListeners();
    } catch (e) {
      debugPrint("Error adding patient: $e");
      rethrow;
    }
  }

  Future<void> updatePatient(Patient updatedPatient) async {
    try {
      await _firebaseService.updatePatient(updatedPatient);
      int index = _patients.indexWhere((p) => p.phoneNumber == updatedPatient.phoneNumber);
      if (index != -1) {
        _patients[index] = updatedPatient;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error updating patient: $e");
      rethrow;
    }
  }

  Future<void> deletePatient(String phoneNumber) async {
    try {
      await _firebaseService.deletePatient(phoneNumber);
      _patients.removeWhere((p) => p.phoneNumber == phoneNumber);
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting patient: $e");
      rethrow;
    }
  }

  Future<Patient?> findByPhoneNumber(String phoneNumber) async {
    try {
      return await _firebaseService.getPatientByPhone(phoneNumber);
    } catch (e) {
      debugPrint("Error finding patient: $e");
      return null;
    }
  }

  // ── Timeline ────────────────────────────────────────────────────────────────
  Future<void> addTimelineEvent(String phoneNumber, Map<String, dynamic> event) async {
    await _firebaseService.addTimelineEvent(phoneNumber, event);
  }

  Stream<dynamic> getTimelineStream(String phoneNumber) {
    return _firebaseService.getTimelineStream(phoneNumber);
  }

  Future<void> deleteTimelineEvent(String phoneNumber, String eventId) async {
    await _firebaseService.deleteTimelineEvent(phoneNumber, eventId);
  }

  Future<void> clearTimeline(String phoneNumber) async {
    await _firebaseService.clearTimeline(phoneNumber);
    notifyListeners();
  }
}
