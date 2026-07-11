class Patient {
  final String id;
  final String name;
  final String phoneNumber;
  final int age;
  final String gender;
  final DateTime lastVisitDate;
  final String healthIssue;
  final String sinceWhen;
  final String symptoms;
  final String medication;
  final String allergies;
  final String notes;
  final bool isHighRisk;
  final String status; // 'recovering' | 'improving' | 'no_improvement'
  final DateTime? consultationValidTill;
  final String? aiSummary;
  final List<Map<String, String>> reports; // [{ 'name': 'Blood Test', 'date': '2024-05-10', 'url': '...' }]

  Patient({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.age = 0,
    this.gender = 'Male',
    required this.lastVisitDate,
    required this.healthIssue,
    this.sinceWhen = '',
    this.symptoms = '',
    required this.medication,
    this.allergies = 'None',
    required this.notes,
    this.isHighRisk = false,
    this.status = 'improving',
    this.consultationValidTill,
    this.aiSummary,
    this.reports = const [],
  });

  Patient copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    int? age,
    String? gender,
    DateTime? lastVisitDate,
    String? healthIssue,
    String? sinceWhen,
    String? symptoms,
    String? medication,
    String? allergies,
    String? notes,
    bool? isHighRisk,
    String? status,
    DateTime? consultationValidTill,
    String? aiSummary,
    List<Map<String, String>>? reports,
  }) {
    return Patient(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      healthIssue: healthIssue ?? this.healthIssue,
      sinceWhen: sinceWhen ?? this.sinceWhen,
      symptoms: symptoms ?? this.symptoms,
      medication: medication ?? this.medication,
      allergies: allergies ?? this.allergies,
      notes: notes ?? this.notes,
      isHighRisk: isHighRisk ?? this.isHighRisk,
      status: status ?? this.status,
      consultationValidTill: consultationValidTill ?? this.consultationValidTill,
      aiSummary: aiSummary ?? this.aiSummary,
      reports: reports ?? this.reports,
    );
  }

  factory Patient.fromJson(Map<String, dynamic> json, String id) {
    return Patient(
      id: id,
      name: json['name'] ?? 'Unknown',
      phoneNumber: json['phone'] ?? json['phoneNumber'] ?? '',
      age: json['age'] ?? 0,
      gender: json['gender'] ?? 'Male',
      lastVisitDate: json['last_visit'] != null
          ? DateTime.tryParse(json['last_visit']) ?? DateTime.now()
          : DateTime.now(),
      healthIssue: json['issue'] ?? json['healthIssue'] ?? '',
      sinceWhen: json['sinceWhen'] ?? '',
      symptoms: json['symptoms'] ?? '',
      medication: json['medication'] ?? '',
      allergies: json['allergies'] ?? 'None',
      notes: json['notes'] ?? '',
      isHighRisk: json['isHighRisk'] ?? false,
      status: json['status'] ?? 'improving',
      consultationValidTill: json['consultationValidTill'] != null
          ? DateTime.tryParse(json['consultationValidTill'])
          : null,
      aiSummary: json['aiSummary'],
      reports: (json['reports'] as List?)?.map((e) => Map<String, String>.from(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phoneNumber,
      'age': age,
      'gender': gender,
      'issue': healthIssue,
      'sinceWhen': sinceWhen,
      'symptoms': symptoms,
      'medication': medication,
      'allergies': allergies,
      'notes': notes,
      'last_visit': lastVisitDate.toIso8601String(),
      'isHighRisk': isHighRisk,
      'status': status,
      'consultationValidTill': consultationValidTill?.toIso8601String(),
      'aiSummary': aiSummary,
      'reports': reports,
    };
  }

  // Status helpers
  String get statusLabel {
    switch (status) {
      case 'recovering': return 'Recovered';
      case 'improving': return 'Improving';
      case 'no_improvement': return 'No Improvement';
      default: return 'Improving';
    }
  }

  // Consultation validity
  String get consultationStatus {
    if (consultationValidTill == null) return 'Not Set';
    final now = DateTime.now();
    final diff = consultationValidTill!.difference(now).inDays;
    if (diff < 0) return 'Expired';
    if (diff <= 3) return 'Expiring Soon';
    return 'Active';
  }

  String get consultationValidTillDisplay {
    if (consultationValidTill == null) return '—';
    final d = consultationValidTill!;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String get lastVisitDisplay {
    final d = lastVisitDate;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return '?';
  }
}
