class PatientRiskProfile {
  final String patientId;
  final int age;
  final List<int> systolicBpHistory;
  final List<int> diastolicBpHistory;
  final double hemoglobinLevel; // in g/dL
  final bool hasPreviousComplications;
  final bool missedMedications3PlusDays;

  const PatientRiskProfile({
    required this.patientId,
    required this.age,
    required this.systolicBpHistory,
    required this.diastolicBpHistory,
    required this.hemoglobinLevel,
    required this.hasPreviousComplications,
    required this.missedMedications3PlusDays,
  });

  bool get isHighRiskAge => age < 18 || age > 35;
  
  bool get hasHighBP {
    if (systolicBpHistory.isEmpty || diastolicBpHistory.isEmpty) return false;
    return systolicBpHistory.last >= 140 || diastolicBpHistory.last >= 90;
  }

  bool get hasSevereAnemia => hemoglobinLevel < 7.0;
  bool get hasModerateAnemia => hemoglobinLevel >= 7.0 && hemoglobinLevel < 10.0;

  bool get isHighRiskPregnancy {
    return isHighRiskAge || hasHighBP || hasSevereAnemia || hasPreviousComplications;
  }

  String get primaryRiskLabel {
    if (missedMedications3PlusDays) return 'Medicines Missed 3+ Days';
    if (hasHighBP) return 'High BP Alert';
    if (hasSevereAnemia) return 'Severe Anemia';
    if (isHighRiskAge) return 'Age Risk Factor';
    if (hasPreviousComplications) return 'Prior Complications';
    if (hasModerateAnemia) return 'Moderate Anemia';
    return 'Stable';
  }

  int get triagePriority {
    if (missedMedications3PlusDays) return 0; // Most urgent action required by ASHA
    if (isHighRiskPregnancy) return 1;
    if (hasModerateAnemia) return 2;
    return 3; // Stable
  }
}
