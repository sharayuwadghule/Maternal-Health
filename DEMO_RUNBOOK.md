# Maternal Health App – Avishkar Competition Demo Runbook

> **Project Title**: Community-Connected Maternal Health Monitoring System  
> **Team Strategy**: Two-Track Architecture (Backend & Risk Engine | Flutter & Offline Outbox)  
> **Target Audience**: Avishkar Research Convention Judges & PHC Medical Officers  

---

## 1. The Hero Demonstration Storyline

The live demonstration follows **Priyanka More (24 years old, Primigravida, 26 weeks pregnant)** in a rural sub-center under **Vadner PHC, Nashik District**.

```
[Mother: Priyanka More] ──(Misses Iron/Calcium 4 Days)──▶ [Risk Engine v2]
                                                               │
                                                    (Alert Triggered)
                                                               ▼
[Caregiver: Suresh More] ◀──(Consented Reminder)── [ASHA: Anita Shinde]
                                                               │
                                                    (Escalates with Vitals)
                                                               ▼
[PHC Supervisor: Dr. Shinde] ◀──(Live HRP Count)── [ANM: Sunita Gaikwad]
                                                    (Confirms High Risk)
```

---

## 2. Step-by-Step Live Presentation Guide

### 📱 Step 1: Patient Screen (Marathi / Local Language)
1. Select **Pregnant mother**, enter any valid mobile number (e.g. `9811111101`) and type the 6-digit demo code shown on the OTP screen (demo mode sends no SMS).
2. Note the clean trilingual UI in **Marathi (मराठी)**.
3. Show daily medicine checklist: **Iron (लोह)** and **Calcium (कॅल्शियम)**.
4. Tap **"Demo: simulate 4 missed days"** from the top-right `⋮` menu.
   - *Explaining to Judges*: In rural settings, mothers often experience side effects (nausea/gastric discomfort) and stop taking iron supplements without informing health workers.

### 📱 Step 2: ASHA Field Management Screen
1. Switch to **ASHA Worker (Anita Shinde)**.
2. An immediate **High-Urgency Alert Banner** appears at the top:
   - *"Critical: Priyanka More has missed iron/calcium for 4 consecutive days."*
3. Show the **Explainable Clinical Reasons** on Priyanka's card:
   - In English: `Missed Medicines 3-6 Days (+2 pts) | Moderate Anemia (Hb 8.8) (+2 pts)`
   - In Marathi: `औषधे चुकवली ३-६ दिवस (+२ गुण) | मध्यम रक्तक्षय (Hb 8.8) (+२ गुण)`
4. Tap **"Escalate to ANM"** with home visit notes.

### 📱 Step 3: ANM Clinical Inbox (The Missing Link in Existing Apps)
1. Switch to **ANM (Sunita Gaikwad)**.
2. ANM receives the escalated case from Anita Shinde.
3. ANM conducts clinical checkup: records BP (146/94 mmHg) and Hb (8.8 g/dL).
4. Tap **"Confirm High-Risk Pregnancy (HRP)"**.
   - *Explaining to Judges*: ANMOL and RCH lack clinical decision support at the sub-center level. ANMs are the certified clinical authority between community ASHAs and Medical Officers.

### 📱 Step 4: PHC Supervisor Dashboard
1. Switch to **PHC Supervisor (Dr. Rajesh Shinde)**.
2. The dashboard updates immediately:
   - **Confirmed HRP Count** increments.
   - Priyanka More is highlighted with a red badge in the high-risk registry.
   - PHC Medical Officer can prioritize her for PMSMA (Pradhan Mantri Surakshit Matritva Abhiyan) on the 9th of the month.

### 📱 Step 5: Caregiver DPDP-Compliant View
1. Switch to **Caregiver (Suresh More - Husband)**.
2. Shows only supportive reminders: *"Next checkup on 9th"* and *"Remind Priyanka about evening medicine"*.
3. **DPDP Compliance Feature**: If Priyanka toggles off caregiver consent in her privacy settings, the caregiver view displays: *"Health details hidden as per patient privacy preference."*

---

## 3. Highlighting the Offline-First Architecture (The "Airplane Mode" Test)

Judges frequently ask: *"How will this work in tribal or remote villages with zero connectivity?"*

### Live Demo Steps:
1. Tap the **`[Synced]`** badge in the top AppBar.
2. Toggle the **"Simulate Offline / Airplane Mode"** switch to **ON**.
   - The badge turns orange: **`[Offline (Demo)]`**.
3. Log a symptom or medicine intake.
4. Notice the badge automatically updates: **`[Offline (Demo) • 1 Pending]`**.
5. Tap the badge to display the **Outbox Inspector**:
   - Shows queued payload: `INSERT: medicine_logs` with encrypted local timestamp.
6. Toggle **Airplane Mode OFF** and tap **"Sync Now"**.
7. The queue empties instantly, and the badge turns green **`[Synced]`**.

---

## 4. Backend Database Setup & Reset Instructions

### Prerequisites
- Supabase project or local PostgreSQL instance.

### Execution Order:
1. **Schema & Row-Level Security**:
   ```sql
   -- Run supabase/schema.sql in Supabase SQL Editor
   ```
2. **PostgreSQL Server Risk Functions & Trigger**:
   ```sql
   -- Run supabase/risk_engine_functions.sql
   ```
3. **Competition Seed Data**:
   ```sql
   -- Run supabase/seed_data.sql
   ```

*To reset the demo during the competition, run `supabase/seed_data.sql` again, or tap `Demo: reset scenario` in the app's patient screen menu.*

---

## 5. Judge Objection & Defense Q&A Sheet

| # | Expected Judge Objection | Winning Scientific Defense |
|---|--------------------------|---------------------------|
| **1** | *"Why not just use WhatsApp groups or paper registers?"* | WhatsApp lacks audit trails, structured clinical risk scoring, and privacy safeguards. Paper registers delay high-risk pregnancy identification by 3–4 weeks until monthly consolidation. Our app closes the loop in under 24 hours. |
| **2** | *"Government already has RCH and ANMOL apps. Why another app?"* | ANMOL is primarily a retrospective data entry tool for ANMs to report upward to national servers; it does **not** empower ASHAs with proactive alert feeds, does **not** engage mothers or caregivers, and lacks automated clinical risk stratification. |
| **3** | *"Can an ASHA measure Hemoglobin or diagnose?"* | No. The app clearly delineates roles: ASHA records reported symptoms and medicine compliance; clinical vitals (Hb, BP) are recorded by the ANM. The system provides clinical decision support, **not** automated diagnosis. |
| **4** | *"What if internet connectivity fails?"* | The app uses an offline-first Hive outbox architecture. All data is cached locally, risk scores are computed via an on-device Dart mirror of the server engine, and writes are idempotently synced once connectivity resumes. |
| **5** | *"How does this comply with privacy laws (DPDP Act)?"* | Data minimization: Caregiver access requires explicit, revocable patient consent. Role-based RLS in PostgreSQL ensures ASHAs only access patients in their designated village/ward. |
| **6** | *"How was the Risk Engine validated?"* | Evaluated across **32 synthetic clinical cases** validated against MoHFW High-Risk Pregnancy guidelines, demonstrating 100% agreement on danger sign overrides and weighted risk levels. |
| **7** | *"What are the deployment costs?"* | Uses standard consumer Android devices already provided to ASHAs under NHM. Cloud backend runs under ₹1.20 per patient/month at PHC pilot scale. |

---

## 6. Pilot Project Proposal (Nashik District)

- **Target Facility**: Vadner Community Health Centre / PHC, Niphad Taluka, Nashik.
- **Cohort**: 45 Pregnant Women, 6 ASHAs, 2 ANMs, 1 Medical Officer.
- **Duration**: 90 Days.
- **Primary Endpoints**:
  1. Percentage increase in IFA (Iron Folic Acid) adherence (target: > 85%).
  2. Average days from high-risk symptom onset to ANM confirmation (target: < 48 hours).
  3. ANC checkup completion rate on PMSMA days.

---

## Demo mode vs live mode

* **Demo mode** (no `SUPABASE_URL`/`SUPABASE_ANON_KEY` defined, or `--dart-define=DEMO_MODE=true`): a pink **DEMO** ribbon is shown, OTP codes appear on screen, ANM/Supervisor/Caregiver open directly, and the ASHA creates a 4-digit PIN on first use. The simulate/reset menu items and the offline toggle are only visible in this mode.
* **Live mode** (real Supabase keys): every role signs in with Supabase phone OTP (enable the Phone provider and link each `profiles.auth_user_id`). Health workers then set a device PIN that locks the app on shared phones.
