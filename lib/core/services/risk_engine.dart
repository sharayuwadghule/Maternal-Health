enum RiskLevel {
  low,
  moderate,
  high;

  String get displayNameEn {
    switch (this) {
      case RiskLevel.high:
        return 'High Risk (HRP)';
      case RiskLevel.moderate:
        return 'Moderate Risk';
      case RiskLevel.low:
        return 'Stable / Low Risk';
    }
  }

  String get displayNameHi {
    switch (this) {
      case RiskLevel.high:
        return 'उच्च जोखिम (HRP)';
      case RiskLevel.moderate:
        return 'मध्यम जोखिम';
      case RiskLevel.low:
        return 'सामान्य / कम जोखिम';
    }
  }

  String get displayNameMr {
    switch (this) {
      case RiskLevel.high:
        return 'उच्च धोका (HRP)';
      case RiskLevel.moderate:
        return 'मध्यम धोका';
      case RiskLevel.low:
        return 'स्थिर / कमी धोका';
    }
  }
}

class RiskAssessmentResult {
  final RiskLevel level;
  final int score;
  final bool isImmediateDanger;
  final List<String> reasonsEn;
  final List<String> reasonsHi;
  final List<String> reasonsMr;

  const RiskAssessmentResult({
    required this.level,
    required this.score,
    required this.isImmediateDanger,
    required this.reasonsEn,
    required this.reasonsHi,
    required this.reasonsMr,
  });

  String get summaryEn => reasonsEn.isEmpty ? 'All vitals normal' : reasonsEn.join(' • ');
  String get summaryHi => reasonsHi.isEmpty ? 'सभी जांच सामान्य' : reasonsHi.join(' • ');
  String get summaryMr => reasonsMr.isEmpty ? 'सर्व तपासण्या सामान्य' : reasonsMr.join(' • ');
}

class RiskEngine {
  /// Evaluates patient risk using MoHFW High-Risk Pregnancy guidelines
  /// and the weighted scoring algorithm defined in Section 6.
  static RiskAssessmentResult evaluate({
    required int age,
    int? systolic,
    int? diastolic,
    int? previousSystolic,
    double? hemoglobin,
    double? previousHemoglobin,
    List<String> dangerSigns = const [],
    bool previousCSection = false,
    bool stillbirthHistory = false,
    bool pregnancyLossHistory = false,
    bool pphHistory = false,
    bool isTwin = false,
    bool hasDiabetes = false,
    bool isRhNegative = false,
    int consecutiveMissedMedsDays = 0,
    bool isOverdueAnc = false,
  }) {
    final List<String> reasonsEn = [];
    final List<String> reasonsHi = [];
    final List<String> reasonsMr = [];

    bool immediateDanger = false;
    int score = 0;

    // ──────────────────────────────────────────────────────────────────────────
    // STEP 1: Danger signs & Critical values (Immediate HIGH regardless of score)
    // ──────────────────────────────────────────────────────────────────────────
    if (hemoglobin != null && hemoglobin < 7.0) {
      immediateDanger = true;
      reasonsEn.add('Severe Anemia (Hb $hemoglobin g/dL < 7.0)');
      reasonsHi.add('गंभीर एनीमिया (Hb $hemoglobin g/dL < 7.0)');
      reasonsMr.add('तीव्र रक्तक्षय/अशक्तपणा (Hb $hemoglobin g/dL < 7.0)');
    }

    if ((systolic != null && systolic >= 160) || (diastolic != null && diastolic >= 110)) {
      immediateDanger = true;
      reasonsEn.add('Severe Hypertension (${systolic ?? 0}/${diastolic ?? 0} mmHg)');
      reasonsHi.add('गंभीर उच्च रक्तचाप (${systolic ?? 0}/${diastolic ?? 0} mmHg)');
      reasonsMr.add('तीव्र उच्च रक्तदाब (${systolic ?? 0}/${diastolic ?? 0} mmHg)');
    }

    if (dangerSigns.contains('vaginal_bleeding')) {
      immediateDanger = true;
      reasonsEn.add('Reported Vaginal Bleeding');
      reasonsHi.add('रक्तस्राव की शिकायत');
      reasonsMr.add('योनीतून रक्तस्त्राव नोंदवला');
    }

    if (dangerSigns.contains('severe_headache') || dangerSigns.contains('severe_headache_visual')) {
      immediateDanger = true;
      reasonsEn.add('Severe Headache / Blurred Vision (Preeclampsia sign)');
      reasonsHi.add('गंभीर सिरदर्द/धुंधलापन (प्री-एक्लेम्पसिया लक्षण)');
      reasonsMr.add('तीव्र डोकेदुखी/अंधुक दृष्टी (प्री-एक्लॅम्पसिया लक्षण)');
    }

    if (dangerSigns.contains('convulsions')) {
      immediateDanger = true;
      reasonsEn.add('Convulsions / Fits');
      reasonsHi.add('दौरे / आक्षेप');
      reasonsMr.add('फेफरे / झटके');
    }

    if (dangerSigns.contains('severe_abdominal_pain')) {
      immediateDanger = true;
      reasonsEn.add('Severe Abdominal Pain');
      reasonsHi.add('पेट में तेज दर्द');
      reasonsMr.add('पोटात तीव्र वेदना');
    }

    if (dangerSigns.contains('leaking_fluid')) {
      immediateDanger = true;
      reasonsEn.add('Leaking Amniotic Fluid');
      reasonsHi.add('योनि से पानी आना');
      reasonsMr.add('योनीतून पाणी जाणे');
    }

    if (dangerSigns.contains('absent_fetal_movement') || dangerSigns.contains('reduced_fetal_movement')) {
      immediateDanger = true;
      reasonsEn.add('Reduced / Absent Fetal Movement');
      reasonsHi.add('शिशु की हलचल में कमी');
      reasonsMr.add('बाळाची हालचाल कमी किंवा बंद');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // STEP 2: Weighted Points Scoring
    // ──────────────────────────────────────────────────────────────────────────
    // Age factor
    if (age < 18 || age > 35) {
      score += 2;
      reasonsEn.add('Age Risk Factor ($age yrs)');
      reasonsHi.add('आयु जोखिम कारक ($age वर्ष)');
      reasonsMr.add('वयाचा धोका घटक ($age वर्षे)');
    }

    // Stage 1 BP: 140-159 systolic OR 90-109 diastolic
    if ((systolic != null && systolic >= 140 && systolic < 160) ||
        (diastolic != null && diastolic >= 90 && diastolic < 110)) {
      score += 3;
      reasonsEn.add('Stage 1 High BP (${systolic ?? 0}/${diastolic ?? 0} mmHg)');
      reasonsHi.add('स्टेज 1 उच्च रक्तचाप (${systolic ?? 0}/${diastolic ?? 0} mmHg)');
      reasonsMr.add('स्टेज 1 उच्च रक्तदाब (${systolic ?? 0}/${diastolic ?? 0} mmHg)');
    }

    // Hemoglobin (Moderate or Mild)
    if (hemoglobin != null) {
      if (hemoglobin >= 7.0 && hemoglobin < 10.0) {
        score += 2;
        reasonsEn.add('Moderate Anemia (Hb $hemoglobin g/dL)');
        reasonsHi.add('मध्यम एनीमिया (Hb $hemoglobin g/dL)');
        reasonsMr.add('मध्यम अशक्तपणा (Hb $hemoglobin g/dL)');
      } else if (hemoglobin >= 10.0 && hemoglobin < 11.0) {
        score += 1;
        reasonsEn.add('Mild Anemia (Hb $hemoglobin g/dL)');
        reasonsHi.add('हल्का एनीमिया (Hb $hemoglobin g/dL)');
        reasonsMr.add('किरकोळ अशक्तपणा (Hb $hemoglobin g/dL)');
      }
    }

    // Obstetric history (2 pts each, capped at 4 pts)
    int obstetricPoints = 0;
    if (previousCSection) {
      obstetricPoints += 2;
      reasonsEn.add('Prior C-Section');
      reasonsHi.add('पूर्व सिजेरियन डिलीवरी');
      reasonsMr.add('पूर्वीचे सिझेरियन ऑपरेशन');
    }
    if (stillbirthHistory) {
      obstetricPoints += 2;
      reasonsEn.add('Prior Stillbirth History');
      reasonsHi.add('पूर्व मृत जन्म इतिहास');
      reasonsMr.add('पूर्वी मृत बाळ जन्माचा इतिहास');
    }
    if (pregnancyLossHistory) {
      obstetricPoints += 2;
      reasonsEn.add('Prior Pregnancy Loss');
      reasonsHi.add('पूर्व गर्भपात इतिहास');
      reasonsMr.add('पूर्वी गर्भपात इतिहास');
    }
    if (pphHistory) {
      obstetricPoints += 2;
      reasonsEn.add('History of PPH');
      reasonsHi.add('प्रसवोत्तर रक्तस्राव (PPH) इतिहास');
      reasonsMr.add('प्रसूतीनंतर जास्त रक्तस्त्रावाचा (PPH) इतिहास');
    }
    score += obstetricPoints.clamp(0, 4);

    // Twin pregnancy
    if (isTwin) {
      score += 3;
      reasonsEn.add('Twin Pregnancy');
      reasonsHi.add('जुड़वां गर्भावस्था');
      reasonsMr.add('जुळे गर्भधारणा');
    }

    // Diabetes
    if (hasDiabetes) {
      score += 2;
      reasonsEn.add('Gestational / Pre-existing Diabetes');
      reasonsHi.add('मधुमेह');
      reasonsMr.add('मधुमेह (डायबेटिस)');
    }

    // Rh-negative
    if (isRhNegative) {
      score += 1;
      reasonsEn.add('Rh-Negative Blood Group');
      reasonsHi.add('Rh-नेगेटिव रक्त समूह');
      reasonsMr.add('Rh-निगेटिव्ह रक्तगट');
    }

    // Missed medicines
    if (consecutiveMissedMedsDays >= 7) {
      score += 3;
      reasonsEn.add('Missed Medicines 7+ Days ($consecutiveMissedMedsDays days)');
      reasonsHi.add('7+ दिनों से दवा छूटी ($consecutiveMissedMedsDays दिन)');
      reasonsMr.add('७+ दिवस औषधे चुकली ($consecutiveMissedMedsDays दिवस)');
    } else if (consecutiveMissedMedsDays >= 3) {
      score += 2;
      reasonsEn.add('Missed Medicines 3-6 Days ($consecutiveMissedMedsDays days)');
      reasonsHi.add('3-6 दिनों से दवा छूटी ($consecutiveMissedMedsDays दिन)');
      reasonsMr.add('३-६ दिवस औषधे चुकली ($consecutiveMissedMedsDays दिवस)');
    }

    // Overdue ANC checkup
    if (isOverdueAnc) {
      score += 1;
      reasonsEn.add('Overdue ANC Checkup');
      reasonsHi.add('प्रसवपूर्व जांच बकाया');
      reasonsMr.add('तपासणी प्रलंबित');
    }

    // Trends: BP rising >= 20 mmHg
    if (systolic != null && previousSystolic != null && (systolic - previousSystolic) >= 20) {
      score += 2;
      reasonsEn.add('Systolic BP Rising (+${systolic - previousSystolic} mmHg)');
      reasonsHi.add('सिस्टोलिक BP में वृद्धि (+${systolic - previousSystolic} mmHg)');
      reasonsMr.add('सिस्टोलिक BP मध्ये वाढ (+${systolic - previousSystolic} mmHg)');
    }

    // Trends: Hb falling >= 1.0 g/dL
    if (hemoglobin != null && previousHemoglobin != null && (previousHemoglobin - hemoglobin) >= 1.0) {
      score += 1;
      final drop = (previousHemoglobin - hemoglobin).toStringAsFixed(1);
      reasonsEn.add('Hemoglobin Falling (-$drop g/dL)');
      reasonsHi.add('हीमोग्लोबिन में गिरावट (-$drop g/dL)');
      reasonsMr.add('हिमोग्लोबिनमध्ये घट (-$drop g/dL)');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // STEP 3: Determine Risk Level
    // ──────────────────────────────────────────────────────────────────────────
    RiskLevel level;
    if (immediateDanger || score >= 5) {
      level = RiskLevel.high;
    } else if (score >= 3) {
      level = RiskLevel.moderate;
    } else {
      level = RiskLevel.low;
    }

    return RiskAssessmentResult(
      level: level,
      score: score,
      isImmediateDanger: immediateDanger,
      reasonsEn: reasonsEn,
      reasonsHi: reasonsHi,
      reasonsMr: reasonsMr,
    );
  }
}
