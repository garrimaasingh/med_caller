import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/patient.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference scoped to current user
  CollectionReference get _patientsRef => _db.collection('users').doc(_currentDoctorId).collection('patients');

  CollectionReference _timelineRef(String patientPhone) => 
      _patientsRef.doc(patientPhone).collection('timeline');

  // Helper to ensure doctor is logged in
  String get _currentDoctorId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Unauthenticated: Doctor must be logged in.');
    }
    return user.uid;
  }

  // Auth Operations (Setup)
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;

  // CRUD Operations

  /// Add a new patient
  /// Uses phone number as document ID to allow quick retrieval and ensure uniqueness
  Future<void> addPatient(Patient patient) async {
    try {
      final docId = patient.phoneNumber;
      
      // Store patient data scoped to current doctor. No need to store doctor_id directly.
      Map<String, dynamic> data = patient.toJson();
      
      await _patientsRef.doc(docId).set(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch patient data using phone number
  /// Instantly fetch patient data if provided. Returns Patient or null if not found.
  Future<Patient?> getPatientByPhone(String phoneNumber) async {
    try {
      final docSnapshot = await _patientsRef.doc(phoneNumber).get();
      
      if (docSnapshot.exists) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        return Patient.fromJson(data, docSnapshot.id);
      }
      return null; // Return null representing "Unknown Patient"
    } catch (e) {
      // Return null representing "Unknown Patient" in case of error (or rethrow if preferred)
      return null;
    }
  }

  /// Update an existing patient's details
  Future<void> updatePatient(Patient patient) async {
    try {
      final docId = patient.phoneNumber;
      
      // Only allow updating if this patient belongs to the logged in doctor
      // Could also rely on security rules, but good practice to check logic or just rely on rules.
      Map<String, dynamic> data = patient.toJson();
      
      await _patientsRef.doc(docId).update(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a patient record
  Future<void> deletePatient(String phoneNumber) async {
    try {
      await _patientsRef.doc(phoneNumber).delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch all patients for the current doctor (useful for Dashboard)
  Future<List<Patient>> getDoctorsPatients() async {
    try {
      final querySnapshot = await _patientsRef.get();

      return querySnapshot.docs
          .map((doc) => Patient.fromJson(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ── Timeline Operations ──────────────────────────────────────────────────────

  /// Add a timeline event to a patient
  Future<void> addTimelineEvent(String phoneNumber, Map<String, dynamic> event) async {
    try {
      await _timelineRef(phoneNumber).add({
        ...event,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get real-time stream of timeline events
  Stream<QuerySnapshot> getTimelineStream(String phoneNumber) {
    return _timelineRef(phoneNumber)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Delete a specific timeline event
  Future<void> deleteTimelineEvent(String phoneNumber, String eventId) async {
    try {
      await _timelineRef(phoneNumber).doc(eventId).delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Clear all timeline events for a patient
  Future<void> clearTimeline(String phoneNumber) async {
    try {
      final snapshot = await _timelineRef(phoneNumber).get();
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
}
