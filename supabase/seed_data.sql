-- ============================================================================
-- MATERNAL HEALTH PLATFORM - SEED & RESET SCRIPT (DEMO READY)
-- Safe to re-run at any time to reset the demo environment.
-- ============================================================================

-- Clean existing demo data in reverse dependency order
TRUNCATE TABLE public.audit_logs CASCADE;
TRUNCATE TABLE public.consents CASCADE;
TRUNCATE TABLE public.sos_events CASCADE;
TRUNCATE TABLE public.vaccinations CASCADE;
TRUNCATE TABLE public.escalations CASCADE;
TRUNCATE TABLE public.alerts CASCADE;
TRUNCATE TABLE public.risk_assessments CASCADE;
TRUNCATE TABLE public.visits CASCADE;
TRUNCATE TABLE public.medicine_logs CASCADE;
TRUNCATE TABLE public.medicine_plans CASCADE;
TRUNCATE TABLE public.caregiver_links CASCADE;
TRUNCATE TABLE public.assignments CASCADE;
TRUNCATE TABLE public.patients CASCADE;
TRUNCATE TABLE public.profiles CASCADE;
TRUNCATE TABLE public.phcs CASCADE;

-- ----------------------------------------------------------------------------
-- 1. PRIMARY HEALTH CENTRE (PHC)
-- ----------------------------------------------------------------------------
INSERT INTO public.phcs (id, name, district, state, contact_number)
VALUES (
    '11111111-1111-1111-1111-111111111111',
    'Trimbakeshwar Rural PHC',
    'Nashik',
    'Maharashtra',
    '+91-253-2456789'
);

-- ----------------------------------------------------------------------------
-- 2. USER PROFILES
-- ----------------------------------------------------------------------------
-- Supervisor
INSERT INTO public.profiles (id, role, name, phone, language, phc_id, pin_hash) VALUES
('22222222-2222-2222-2222-222222222221', 'supervisor', 'Dr. Rajesh Patil (Medical Officer)', '9800000001', 'mr', '11111111-1111-1111-1111-111111111111', NULL);

-- 2 ANMs
INSERT INTO public.profiles (id, role, name, phone, language, phc_id, pin_hash) VALUES
('22222222-2222-2222-2222-222222222231', 'anm', 'ANM Sunita Gaikwad', '9800000011', 'mr', '11111111-1111-1111-1111-111111111111', NULL),
('22222222-2222-2222-2222-222222222232', 'anm', 'ANM Rekha Shinde', '9800000012', 'mr', '11111111-1111-1111-1111-111111111111', NULL);

-- 4 ASHA Workers
INSERT INTO public.profiles (id, role, name, phone, language, phc_id, pin_hash) VALUES
('22222222-2222-2222-2222-222222222241', 'asha', 'Savita Tai (ASHA)', '9800000021', 'mr', '11111111-1111-1111-1111-111111111111', NULL),
('22222222-2222-2222-2222-222222222242', 'asha', 'Mangala Kadam (ASHA)', '9800000022', 'mr', '11111111-1111-1111-1111-111111111111', NULL),
('22222222-2222-2222-2222-222222222243', 'asha', 'Pushpa Pawar (ASHA)', '9800000023', 'mr', '11111111-1111-1111-1111-111111111111', NULL),
('22222222-2222-2222-2222-222222222244', 'asha', 'Usha Jadhav (ASHA)', '9800000024', 'mr', '11111111-1111-1111-1111-111111111111', NULL);

-- Patients (Mothers)
INSERT INTO public.profiles (id, role, name, phone, language, phc_id) VALUES
('33333333-3333-3333-3333-333333333301', 'patient', 'Priyanka More (Demo Mother)', '9811111101', 'mr', '11111111-1111-1111-1111-111111111111'),
('33333333-3333-3333-3333-333333333302', 'patient', 'Sita Devi', '9811111102', 'hi', '11111111-1111-1111-1111-111111111111'),
('33333333-3333-3333-3333-333333333303', 'patient', 'Meena Rao', '9811111103', 'mr', '11111111-1111-1111-1111-111111111111'),
('33333333-3333-3333-3333-333333333304', 'patient', 'Pooja Singh', '9811111104', 'en', '11111111-1111-1111-1111-111111111111'),
('33333333-3333-3333-3333-333333333305', 'patient', 'Aarti Deshmukh', '9811111105', 'mr', '11111111-1111-1111-1111-111111111111');

-- Caregiver (Priyanka's Husband)
INSERT INTO public.profiles (id, role, name, phone, language, phc_id) VALUES
('44444444-4444-4444-4444-444444444401', 'caregiver', 'Sachin More (Husband)', '9822222201', 'mr', '11111111-1111-1111-1111-111111111111');

-- ----------------------------------------------------------------------------
-- 3. PATIENTS CLINICAL DETAILS
-- ----------------------------------------------------------------------------
INSERT INTO public.patients (id, profile_id, date_of_birth, lmp, edd, height_cm, blood_group, previous_c_section, stillbirth_history, is_confirmed_hrp, hrp_category) VALUES
-- Priyanka More (26 yrs, 6th month, Missed meds alert!)
('55555555-5555-5555-5555-555555555501', '33333333-3333-3333-3333-333333333301', '1998-04-12', '2026-04-01', '2027-01-06', 152.0, 'B+', false, false, false, NULL),
-- Sita Devi (17 yrs - Teenage pregnancy, High BP)
('55555555-5555-5555-5555-555555555502', '33333333-3333-3333-3333-333333333302', '2009-02-15', '2026-03-10', '2026-12-15', 148.0, 'O+', false, false, true, 'teenage_pregnancy_high_bp'),
-- Meena Rao (28 yrs, Severe Anemia Hb 6.8)
('55555555-5555-5555-5555-555555555503', '33333333-3333-3333-3333-333333333303', '1996-08-20', '2026-05-01', '2027-02-05', 155.0, 'AB-', false, true, true, 'severe_anemia'),
-- Pooja Singh (25 yrs, Stable pregnancy)
('55555555-5555-5555-5555-555555555504', '33333333-3333-3333-3333-333333333304', '1999-11-05', '2026-06-15', '2027-03-22', 158.0, 'A+', false, false, false, NULL),
-- Aarti Deshmukh (36 yrs, Previous C-Section, Moderate Anemia Hb 8.8)
('55555555-5555-5555-5555-555555555505', '33333333-3333-3333-3333-333333333305', '1988-09-14', '2026-02-20', '2026-11-27', 150.0, 'O-', true, false, true, 'previous_c_section_moderate_anemia');

-- ----------------------------------------------------------------------------
-- 4. ASSIGNMENTS
-- ----------------------------------------------------------------------------
-- Assign Priyanka, Sita, and Meena to Savita Tai (ASHA) & ANM Sunita
INSERT INTO public.assignments (patient_id, asha_id, anm_id, phc_id) VALUES
('55555555-5555-5555-5555-555555555501', '22222222-2222-2222-2222-222222222241', '22222222-2222-2222-2222-222222222231', '11111111-1111-1111-1111-111111111111'),
('55555555-5555-5555-5555-555555555502', '22222222-2222-2222-2222-222222222241', '22222222-2222-2222-2222-222222222231', '11111111-1111-1111-1111-111111111111'),
('55555555-5555-5555-5555-555555555503', '22222222-2222-2222-2222-222222222241', '22222222-2222-2222-2222-222222222231', '11111111-1111-1111-1111-111111111111'),
-- Assign Pooja to Mangala Kadam (ASHA) & ANM Rekha
('55555555-5555-5555-5555-555555555504', '22222222-2222-2222-2222-222222222242', '22222222-2222-2222-2222-222222222232', '11111111-1111-1111-1111-111111111111'),
-- Assign Aarti to Pushpa Pawar (ASHA) & ANM Rekha
('55555555-5555-5555-5555-555555555505', '22222222-2222-2222-2222-222222222243', '22222222-2222-2222-2222-222222222232', '11111111-1111-1111-1111-111111111111');

-- ----------------------------------------------------------------------------
-- 5. CAREGIVER LINK WITH CONSENT
-- ----------------------------------------------------------------------------
INSERT INTO public.caregiver_links (patient_id, caregiver_profile_id, relationship, consent_given, consent_given_at)
VALUES (
    '55555555-5555-5555-5555-555555555501',
    '44444444-4444-4444-4444-444444444401',
    'Husband',
    true,
    now()
);

-- ----------------------------------------------------------------------------
-- 6. MEDICINE PLANS
-- ----------------------------------------------------------------------------
INSERT INTO public.medicine_plans (patient_id, medicine, dosage, start_date) VALUES
('55555555-5555-5555-5555-555555555501', 'Iron', '1 tablet daily', '2026-05-01'),
('55555555-5555-5555-5555-555555555501', 'Calcium', '1 tablet daily', '2026-05-01'),
('55555555-5555-5555-5555-555555555501', 'Folic Acid', '1 tablet daily', '2026-05-01');

-- ----------------------------------------------------------------------------
-- 7. MEDICINE LOGS (Demonstrating 4 consecutive missed days for Priyanka)
-- ----------------------------------------------------------------------------
-- Past adherence (Taken)
INSERT INTO public.medicine_logs (patient_id, medicine, log_date, taken) VALUES
('55555555-5555-5555-5555-555555555501', 'Iron', CURRENT_DATE - INTERVAL '7 day', true),
('55555555-5555-5555-5555-555555555501', 'Calcium', CURRENT_DATE - INTERVAL '7 day', true),
('55555555-5555-5555-5555-555555555501', 'Iron', CURRENT_DATE - INTERVAL '6 day', true),
('55555555-5555-5555-5555-555555555501', 'Calcium', CURRENT_DATE - INTERVAL '6 day', true),
('55555555-5555-5555-5555-555555555501', 'Iron', CURRENT_DATE - INTERVAL '5 day', true),
('55555555-5555-5555-5555-555555555501', 'Calcium', CURRENT_DATE - INTERVAL '5 day', true),
-- Consecutive missed days (4 days missed)
('55555555-5555-5555-5555-555555555501', 'Iron', CURRENT_DATE - INTERVAL '4 day', false),
('55555555-5555-5555-5555-555555555501', 'Calcium', CURRENT_DATE - INTERVAL '4 day', false),
('55555555-5555-5555-5555-555555555501', 'Iron', CURRENT_DATE - INTERVAL '3 day', false),
('55555555-5555-5555-5555-555555555501', 'Calcium', CURRENT_DATE - INTERVAL '3 day', false),
('55555555-5555-5555-5555-555555555501', 'Iron', CURRENT_DATE - INTERVAL '2 day', false),
('55555555-5555-5555-5555-555555555501', 'Calcium', CURRENT_DATE - INTERVAL '2 day', false),
('55555555-5555-5555-5555-555555555501', 'Iron', CURRENT_DATE - INTERVAL '1 day', false),
('55555555-5555-5555-5555-555555555501', 'Calcium', CURRENT_DATE - INTERVAL '1 day', false);

-- ----------------------------------------------------------------------------
-- 8. PAST VISITS & VITALS
-- ----------------------------------------------------------------------------
INSERT INTO public.visits (patient_id, recorded_by, recorded_by_role, visit_date, systolic, diastolic, hemoglobin, weight_kg, notes) VALUES
-- Priyanka (Vitals stable initially)
('55555555-5555-5555-5555-555555555501', '22222222-2222-2222-2222-222222222241', 'asha', CURRENT_DATE - INTERVAL '14 day', 118, 76, 11.2, 54.5, 'Regular home visit. Advised diet and hydration.'),
-- Sita Devi (High BP 146/94 recorded by ANM)
('55555555-5555-5555-5555-555555555502', '22222222-2222-2222-2222-222222222231', 'anm', CURRENT_DATE - INTERVAL '5 day', 146, 94, 10.4, 49.0, 'Stage 1 hypertension detected. Close monitoring advised.'),
-- Meena Rao (Severe anemia Hb 6.8 g/dL recorded by ANM)
('55555555-5555-5555-5555-555555555503', '22222222-2222-2222-2222-222222222231', 'anm', CURRENT_DATE - INTERVAL '2 day', 110, 70, 6.8, 51.0, 'Critical severe anemia. Referred for Iron Sucrose infusion.');

-- ----------------------------------------------------------------------------
-- 9. CLOSED-LOOP ALERTS
-- ----------------------------------------------------------------------------
INSERT INTO public.alerts (id, patient_id, type, severity, status, assigned_to, message) VALUES
-- Critical alert for Priyanka More (Missed medications 3+ days)
(
    '66666666-6666-6666-6666-666666666601',
    '55555555-5555-5555-5555-555555555501',
    'missed_dose_3_days',
    'urgent',
    'open',
    '22222222-2222-2222-2222-222222222241', -- Savita Tai (ASHA)
    '🚨 Medicine Alert: Priyanka More has missed Iron & Calcium for 4 consecutive days!'
),
-- High BP alert for Sita Devi
(
    '66666666-6666-6666-6666-666666666602',
    '55555555-5555-5555-5555-555555555502',
    'high_bp',
    'urgent',
    'escalated',
    '22222222-2222-2222-2222-222222222241',
    'High BP Alert: Sita Devi systolic BP reached 146 mmHg.'
);

-- ----------------------------------------------------------------------------
-- 10. ESCALATION (Sita Devi escalated to ANM)
-- ----------------------------------------------------------------------------
INSERT INTO public.escalations (alert_id, escalated_by, escalated_to, decision, decision_notes, decided_by, decided_at)
VALUES (
    '66666666-6666-6666-6666-666666666602',
    '22222222-2222-2222-2222-222222222241', -- Savita Tai
    '22222222-2222-2222-2222-222222222231', -- ANM Sunita
    'confirm_hrp',
    'Confirmed High-Risk Pregnancy due to Gestational Hypertension and age < 18.',
    '22222222-2222-2222-2222-222222222231',
    now()
);

-- Done!
