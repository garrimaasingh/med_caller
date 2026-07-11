class AIHistory {
  final BasicInfo basicInfo;
  final MedicalHistory medicalHistory;
  final Lifestyle lifestyle;
  final MentalEmotionalState mentalEmotionalState;
  final FamilyHistory familyHistory;
  final PhysicalTendencies physicalTendencies;
  final List<String> timeline;
  final String doctorQuickSummary;
  final String riskLevel;
  final bool followUpRequired;

  AIHistory({
    required this.basicInfo,
    required this.medicalHistory,
    required this.lifestyle,
    required this.mentalEmotionalState,
    required this.familyHistory,
    required this.physicalTendencies,
    required this.timeline,
    required this.doctorQuickSummary,
    required this.riskLevel,
    required this.followUpRequired,
  });

  factory AIHistory.fromJson(Map<String, dynamic> json) {
    return AIHistory(
      basicInfo: BasicInfo.fromJson(json['basic_info'] ?? {}),
      medicalHistory: MedicalHistory.fromJson(json['medical_history'] ?? {}),
      lifestyle: Lifestyle.fromJson(json['lifestyle'] ?? {}),
      mentalEmotionalState: MentalEmotionalState.fromJson(json['mental_emotional_state'] ?? {}),
      familyHistory: FamilyHistory.fromJson(json['family_history'] ?? {}),
      physicalTendencies: PhysicalTendencies.fromJson(json['physical_tendencies'] ?? {}),
      timeline: (json['timeline'] as List?)?.map((e) => e.toString()).toList() ?? [],
      doctorQuickSummary: json['doctor_quick_summary']?.toString() ?? '',
      riskLevel: json['risk_level']?.toString() ?? 'low',
      followUpRequired: json['follow_up_required'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'basic_info': basicInfo.toJson(),
    'medical_history': medicalHistory.toJson(),
    'lifestyle': lifestyle.toJson(),
    'mental_emotional_state': mentalEmotionalState.toJson(),
    'family_history': familyHistory.toJson(),
    'physical_tendencies': physicalTendencies.toJson(),
    'timeline': timeline,
    'doctor_quick_summary': doctorQuickSummary,
    'risk_level': riskLevel,
    'follow_up_required': followUpRequired,
  };
}

class BasicInfo {
  final String? name;
  final String? age;
  final String? gender;
  final String? occupation;

  BasicInfo({this.name, this.age, this.gender, this.occupation});

  factory BasicInfo.fromJson(Map<String, dynamic> json) => BasicInfo(
    name: json['name']?.toString(),
    age: json['age']?.toString(),
    gender: json['gender']?.toString(),
    occupation: json['occupation']?.toString(),
  );

  Map<String, dynamic> toJson() => {'name': name, 'age': age, 'gender': gender, 'occupation': occupation};
}

class MedicalHistory {
  final List<String> currentSymptoms;
  final List<String> pastDiseases;
  final List<String> chronicIllnesses;
  final List<String> allergies;
  final List<String> ongoingMedicines;
  final List<String> surgeries;
  final String? bloodPressure;
  final String? diabetes;
  final String? thyroid;
  final String? asthma;
  final List<String> digestionIssues;

  MedicalHistory({
    required this.currentSymptoms,
    required this.pastDiseases,
    required this.chronicIllnesses,
    required this.allergies,
    required this.ongoingMedicines,
    required this.surgeries,
    this.bloodPressure,
    this.diabetes,
    this.thyroid,
    this.asthma,
    required this.digestionIssues,
  });

  factory MedicalHistory.fromJson(Map<String, dynamic> json) => MedicalHistory(
    currentSymptoms: (json['current_symptoms'] as List?)?.map((e) => e.toString()).toList() ?? [],
    pastDiseases: (json['past_diseases'] as List?)?.map((e) => e.toString()).toList() ?? [],
    chronicIllnesses: (json['chronic_illnesses'] as List?)?.map((e) => e.toString()).toList() ?? [],
    allergies: (json['allergies'] as List?)?.map((e) => e.toString()).toList() ?? [],
    ongoingMedicines: (json['ongoing_medicines'] as List?)?.map((e) => e.toString()).toList() ?? [],
    surgeries: (json['surgeries'] as List?)?.map((e) => e.toString()).toList() ?? [],
    bloodPressure: json['blood_pressure']?.toString(),
    diabetes: json['diabetes']?.toString(),
    thyroid: json['thyroid']?.toString(),
    asthma: json['asthma']?.toString(),
    digestionIssues: (json['digestion_issues'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'current_symptoms': currentSymptoms,
    'past_diseases': pastDiseases,
    'chronic_illnesses': chronicIllnesses,
    'allergies': allergies,
    'ongoing_medicines': ongoingMedicines,
    'surgeries': surgeries,
    'blood_pressure': bloodPressure,
    'diabetes': diabetes,
    'thyroid': thyroid,
    'asthma': asthma,
    'digestion_issues': digestionIssues,
  };
}

class Lifestyle {
  final String? sleepQuality;
  final String? eatingHabits;
  final String? waterIntake;
  final String? smoking;
  final String? alcohol;
  final String? exercise;
  final String? stressLevel;

  Lifestyle({this.sleepQuality, this.eatingHabits, this.waterIntake, this.smoking, this.alcohol, this.exercise, this.stressLevel});

  factory Lifestyle.fromJson(Map<String, dynamic> json) => Lifestyle(
    sleepQuality: json['sleep_quality']?.toString(),
    eatingHabits: json['eating_habits']?.toString(),
    waterIntake: json['water_intake']?.toString(),
    smoking: json['smoking']?.toString(),
    alcohol: json['alcohol']?.toString(),
    exercise: json['exercise']?.toString(),
    stressLevel: json['stress_level']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'sleep_quality': sleepQuality,
    'eating_habits': eatingHabits,
    'water_intake': waterIntake,
    'smoking': smoking,
    'alcohol': alcohol,
    'exercise': exercise,
    'stress_level': stressLevel,
  };
}

class MentalEmotionalState {
  final String? anxiety;
  final String? anger;
  final String? depression;
  final String? overthinking;
  final String? emotionalSensitivity;
  final String? fear;
  final List<String> moodPatterns;

  MentalEmotionalState({this.anxiety, this.anger, this.depression, this.overthinking, this.emotionalSensitivity, this.fear, required this.moodPatterns});

  factory MentalEmotionalState.fromJson(Map<String, dynamic> json) => MentalEmotionalState(
    anxiety: json['anxiety']?.toString(),
    anger: json['anger']?.toString(),
    depression: json['depression']?.toString(),
    overthinking: json['overthinking']?.toString(),
    emotionalSensitivity: json['emotional_sensitivity']?.toString(),
    fear: json['fear']?.toString(),
    moodPatterns: (json['mood_patterns'] as List?)?.map((e) => e.toString()).toList() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'anxiety': anxiety,
    'anger': anger,
    'depression': depression,
    'overthinking': overthinking,
    'emotional_sensitivity': emotionalSensitivity,
    'fear': fear,
    'mood_patterns': moodPatterns,
  };
}

class FamilyHistory {
  final String? diabetes;
  final String? heartDisease;
  final String? bloodPressure;
  final String? asthma;
  final String? cancer;
  final String? thyroid;

  FamilyHistory({this.diabetes, this.heartDisease, this.bloodPressure, this.asthma, this.cancer, this.thyroid});

  factory FamilyHistory.fromJson(Map<String, dynamic> json) => FamilyHistory(
    diabetes: json['diabetes']?.toString(),
    heartDisease: json['heart_disease']?.toString(),
    bloodPressure: json['blood_pressure']?.toString(),
    asthma: json['asthma']?.toString(),
    cancer: json['cancer']?.toString(),
    thyroid: json['thyroid']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'diabetes': diabetes,
    'heart_disease': heartDisease,
    'blood_pressure': bloodPressure,
    'asthma': asthma,
    'cancer': cancer,
    'thyroid': thyroid,
  };
}

class PhysicalTendencies {
  final String? coldOrHeatSensitivity;
  final String? sweating;
  final String? weakness;
  final String? bodyPain;
  final String? headaches;
  final String? fatigue;

  PhysicalTendencies({this.coldOrHeatSensitivity, this.sweating, this.weakness, this.bodyPain, this.headaches, this.fatigue});

  factory PhysicalTendencies.fromJson(Map<String, dynamic> json) => PhysicalTendencies(
    coldOrHeatSensitivity: json['cold_or_heat_sensitivity']?.toString(),
    sweating: json['sweating']?.toString(),
    weakness: json['weakness']?.toString(),
    bodyPain: json['body_pain']?.toString(),
    headaches: json['headaches']?.toString(),
    fatigue: json['fatigue']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'cold_or_heat_sensitivity': coldOrHeatSensitivity,
    'sweating': sweating,
    'weakness': weakness,
    'body_pain': bodyPain,
    'headaches': headaches,
    'fatigue': fatigue,
  };
}
