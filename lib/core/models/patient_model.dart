class PatientModel {
  final String id;
  final String profileId;
  final String name;
  final String phone;
  final DateTime dateOfBirth;
  final DateTime lmp;
  final DateTime edd;
  final double? heightCm;
  final String? bloodGroup;
  final bool rhNegative;
  final int gravida;
  final int para;
  final bool previousCSection;
  final bool stillbirthHistory;
  final bool pregnancyLossHistory;
  final bool pphHistory;
  final bool isTwin;
  final bool hasDiabetes;
  final bool hasGestationalDiabetes;
  final bool isConfirmedHrp;
  final String? hrpCategory;
  final String? assignedAshaId;
  final String? assignedAnmId;

  const PatientModel({
    required this.id,
    required this.profileId,
    required this.name,
    required this.phone,
    required this.dateOfBirth,
    required this.lmp,
    required this.edd,
    this.heightCm,
    this.bloodGroup,
    this.rhNegative = false,
    this.gravida = 1,
    this.para = 0,
    this.previousCSection = false,
    this.stillbirthHistory = false,
    this.pregnancyLossHistory = false,
    this.pphHistory = false,
    this.isTwin = false,
    this.hasDiabetes = false,
    this.hasGestationalDiabetes = false,
    this.isConfirmedHrp = false,
    this.hrpCategory,
    this.assignedAshaId,
    this.assignedAnmId,
  });

  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  int get gestationalWeeks {
    final diff = DateTime.now().difference(lmp).inDays;
    return (diff / 7).floor().clamp(1, 42);
  }

  int get trimester {
    final weeks = gestationalWeeks;
    if (weeks <= 12) return 1;
    if (weeks <= 27) return 2;
    return 3;
  }

  int get daysUntilNextPmsmaCheckup => daysUntilPmsma(DateTime.now());

  /// Days until the next PMSMA clinic day (9th of every month), counted in
  /// calendar days. Comparing dates only avoids the off-by-one that occurs
  /// when the current time-of-day is included (e.g. "0 days" on the 8th).
  static int daysUntilPmsma(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    var next9th = DateTime(now.year, now.month, 9);
    if (today.isAfter(next9th)) {
      next9th = DateTime(now.year, now.month + 1, 9);
    }
    // Use UTC dates so daylight-saving shifts never produce 23-hour days.
    final a = DateTime.utc(today.year, today.month, today.day);
    final b = DateTime.utc(next9th.year, next9th.month, next9th.day);
    return b.difference(a).inDays;
  }

  /// Copy with updated HRP status.
  PatientModel withHrp({required bool confirmed, String? category}) {
    final map = toMap()
      ..['is_confirmed_hrp'] = confirmed
      ..['hrp_category'] = category;
    return PatientModel.fromMap(map);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'profile_id': profileId,
      'name': name,
      'phone': phone,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'lmp': lmp.toIso8601String(),
      'edd': edd.toIso8601String(),
      'height_cm': heightCm,
      'blood_group': bloodGroup,
      'rh_negative': rhNegative,
      'gravida': gravida,
      'para': para,
      'previous_c_section': previousCSection,
      'stillbirth_history': stillbirthHistory,
      'pregnancy_loss_history': pregnancyLossHistory,
      'pph_history': pphHistory,
      'is_twin': isTwin,
      'has_diabetes': hasDiabetes,
      'has_gestational_diabetes': hasGestationalDiabetes,
      'is_confirmed_hrp': isConfirmedHrp,
      'hrp_category': hrpCategory,
      'assigned_asha_id': assignedAshaId,
      'assigned_anm_id': assignedAnmId,
    };
  }

  factory PatientModel.fromMap(Map<String, dynamic> map) {
    return PatientModel(
      id: map['id']?.toString() ?? '',
      profileId: map['profile_id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Mother',
      phone: map['phone']?.toString() ?? '',
      dateOfBirth: DateTime.tryParse(map['date_of_birth']?.toString() ?? '') ?? DateTime(1998, 1, 1),
      lmp: DateTime.tryParse(map['lmp']?.toString() ?? '') ?? DateTime.now().subtract(const Duration(days: 90)),
      edd: DateTime.tryParse(map['edd']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 190)),
      heightCm: (map['height_cm'] as num?)?.toDouble(),
      bloodGroup: map['blood_group']?.toString(),
      rhNegative: map['rh_negative'] == true,
      gravida: (map['gravida'] as num?)?.toInt() ?? 1,
      para: (map['para'] as num?)?.toInt() ?? 0,
      previousCSection: map['previous_c_section'] == true,
      stillbirthHistory: map['stillbirth_history'] == true,
      pregnancyLossHistory: map['pregnancy_loss_history'] == true,
      pphHistory: map['pph_history'] == true,
      isTwin: map['is_twin'] == true,
      hasDiabetes: map['has_diabetes'] == true,
      hasGestationalDiabetes: map['has_gestational_diabetes'] == true,
      isConfirmedHrp: map['is_confirmed_hrp'] == true,
      hrpCategory: map['hrp_category']?.toString(),
      assignedAshaId: map['assigned_asha_id']?.toString(),
      assignedAnmId: map['assigned_anm_id']?.toString(),
    );
  }
}
