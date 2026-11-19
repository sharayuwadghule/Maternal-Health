-- ============================================================================
-- MATERNAL HEALTH PLATFORM - PRODUCTION SUPABASE DATABASE SCHEMA
-- Complies with MoHFW guidelines & Implementation Plan Data Model
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- 1. PRIMARY HEALTH CENTRES (PHCs)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.phcs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    district TEXT NOT NULL,
    state TEXT NOT NULL DEFAULT 'Maharashtra',
    contact_number TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 2. USER PROFILES
-- ----------------------------------------------------------------------------
-- Roles: 'patient', 'asha', 'anm', 'supervisor', 'caregiver'
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    auth_user_id UUID UNIQUE, -- References auth.users(id) if Supabase Auth is active
    role TEXT NOT NULL CHECK (role IN ('patient', 'asha', 'anm', 'supervisor', 'caregiver')),
    name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE,
    language TEXT NOT NULL DEFAULT 'en' CHECK (language IN ('en', 'hi', 'mr')),
    phc_id UUID REFERENCES public.phcs(id) ON DELETE SET NULL,
    pin_hash TEXT, -- DEPRECATED: unused. Staff PINs are device-local salted hashes (see AuthRepository).
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 3. PATIENTS (Mothers)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.patients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    date_of_birth DATE NOT NULL,
    lmp DATE NOT NULL, -- Last Menstrual Period
    edd DATE NOT NULL, -- Estimated Due Date (Calculated from LMP + 280 days)
    height_cm NUMERIC(5,2),
    blood_group TEXT CHECK (blood_group IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    rh_negative BOOLEAN GENERATED ALWAYS AS (blood_group LIKE '%-') STORED,
    gravida INT DEFAULT 1, -- Total pregnancies
    para INT DEFAULT 0,    -- Deliveries beyond 20 weeks
    
    -- Clinical risk factors
    previous_c_section BOOLEAN DEFAULT false,
    stillbirth_history BOOLEAN DEFAULT false,
    pregnancy_loss_history BOOLEAN DEFAULT false,
    pph_history BOOLEAN DEFAULT false, -- Post-Partum Hemorrhage
    is_twin BOOLEAN DEFAULT false,
    has_diabetes BOOLEAN DEFAULT false,
    has_gestational_diabetes BOOLEAN DEFAULT false,
    
    -- Current Clinical Flags
    is_confirmed_hrp BOOLEAN DEFAULT false, -- Flagged by ANM
    hrp_category TEXT, -- 'severe_anemia', 'preeclampsia', 'obstetric_history', etc.
    confirmed_by_anm_id UUID REFERENCES public.profiles(id),
    confirmed_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 4. HEALTH WORKER ASSIGNMENTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
    asha_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    anm_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    phc_id UUID REFERENCES public.phcs(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    is_active BOOLEAN NOT NULL DEFAULT true,
    UNIQUE(patient_id, asha_id)
);

-- ----------------------------------------------------------------------------
-- 5. CAREGIVER LINKS & CONSENT
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.caregiver_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
    caregiver_profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    relationship TEXT NOT NULL, -- 'Husband', 'Mother', 'Mother-in-law', etc.
    consent_given BOOLEAN NOT NULL DEFAULT false,
    consent_given_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    UNIQUE(patient_id, caregiver_profile_id)
);

-- ----------------------------------------------------------------------------
-- 6. MEDICINE PLANS & DAILY LOGS (Append-Only)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.medicine_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
    medicine TEXT NOT NULL CHECK (medicine IN ('Iron', 'Calcium', 'Folic Acid')),
    dosage TEXT NOT NULL DEFAULT '1 tablet daily',
    schedule_time TIME NOT NULL DEFAULT '09:00:00',
    start_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.medicine_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
    medicine TEXT NOT NULL CHECK (medicine IN ('Iron', 'Calcium', 'Folic Acid')),
    log_date DATE NOT NULL,
    taken BOOLEAN NOT NULL,
    logged_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    synced_from_device BOOLEAN NOT NULL DEFAULT true,
    UNIQUE(patient_id, medicine, log_date)
);

-- ----------------------------------------------------------------------------
-- 7. VISITS & CLINICAL VITALS (Append-Only)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
    recorded_by UUID NOT NULL REFERENCES public.profiles(id),
    recorded_by_role TEXT NOT NULL CHECK (recorded_by_role IN ('asha', 'anm', 'supervisor')),
    visit_date DATE NOT NULL DEFAULT CURRENT_DATE,
    systolic INT,
    diastolic INT,
    hemoglobin NUMERIC(4,2), -- in g/dL
    weight_kg NUMERIC(5,2),
    fundal_height_cm NUMERIC(4,1),
    fetal_heart_rate INT, -- bpm
    danger_signs TEXT[] DEFAULT '{}', -- e.g. {'vaginal_bleeding', 'severe_headache', 'convulsions'}
    notes TEXT,
    location_coordinates POINT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 8. RISK ASSESSMENTS (Explainable Scoring History)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.risk_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
    score INT NOT NULL,
    level TEXT NOT NULL CHECK (level IN ('low', 'moderate', 'high')),
    reasons JSONB NOT NULL DEFAULT '[]'::jsonb, -- Array of readable strings
    trigger TEXT NOT NULL CHECK (trigger IN ('visit', 'missed_dose', 'manual_recalc', 'batch_job')),
    computed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 9. ALERTS (Closed-Loop System)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('missed_dose_3_days', 'high_bp', 'severe_anemia', 'danger_sign_reported', 'overdue_anc')),
    severity TEXT NOT NULL CHECK (severity IN ('urgent', 'warning', 'info')),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'escalated', 'closed')),
    assigned_to UUID REFERENCES public.profiles(id), -- Assigned ASHA
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    acknowledged_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    closed_by UUID REFERENCES public.profiles(id),
    resolution_notes TEXT
);

-- ----------------------------------------------------------------------------
-- 10. ESCALATIONS (ASHA -> ANM -> Supervisor Chain)
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.escalations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_id UUID NOT NULL REFERENCES public.alerts(id) ON DELETE CASCADE,
    escalated_by UUID NOT NULL REFERENCES public.profiles(id),
    escalated_to UUID NOT NULL REFERENCES public.profiles(id), -- Target ANM
    decision TEXT CHECK (decision IN ('confirm_hrp', 'clear', 'refer_to_phc')),
    decision_notes TEXT,
    decided_by UUID REFERENCES public.profiles(id),
    decided_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 11. VACCINATIONS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.vaccinations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
    vaccine_name TEXT NOT NULL, -- 'TT-1', 'TT-2', 'TT-Booster', 'Influenza'
    due_date DATE NOT NULL,
    given_date DATE,
    given_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 12. SOS EVENTS
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sos_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES public.patients(id) ON DELETE CASCADE,
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'responded', 'resolved')),
    resolved_at TIMESTAMPTZ
);

-- ----------------------------------------------------------------------------
-- 13. CONSENT & AUDIT LOG
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    consent_type TEXT NOT NULL, -- 'data_collection', 'caregiver_sharing', 'sms_notifications'
    text_version TEXT NOT NULL DEFAULT '1.0',
    consented BOOLEAN NOT NULL DEFAULT true,
    consented_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id),
    action TEXT NOT NULL, -- 'LOGIN', 'READ_HEALTH_RECORD', 'SUBMIT_VISIT', 'CONFIRM_HRP'
    table_name TEXT,
    record_id UUID,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- INDEXES FOR FAST QUERYING & DASHBOARDS
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_assignments_asha ON public.assignments(asha_id);
CREATE INDEX IF NOT EXISTS idx_assignments_anm ON public.assignments(anm_id);
CREATE INDEX IF NOT EXISTS idx_assignments_patient ON public.assignments(patient_id);
CREATE INDEX IF NOT EXISTS idx_medicine_logs_patient_date ON public.medicine_logs(patient_id, log_date DESC);
CREATE INDEX IF NOT EXISTS idx_visits_patient_date ON public.visits(patient_id, visit_date DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_assigned_status ON public.alerts(assigned_to, status);
CREATE INDEX IF NOT EXISTS idx_alerts_patient ON public.alerts(patient_id);
CREATE INDEX IF NOT EXISTS idx_patients_hrp ON public.patients(is_confirmed_hrp);

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================
ALTER TABLE public.phcs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.caregiver_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicine_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicine_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.risk_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.escalations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vaccinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sos_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Helper function: Get Current User's Profile ID
CREATE OR REPLACE FUNCTION public.current_profile_id()
RETURNS UUID AS $$
    SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- Helper function: Get Current User's Role
CREATE OR REPLACE FUNCTION public.current_profile_role()
RETURNS TEXT AS $$
    SELECT role FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- 1. Profiles Policies
CREATE POLICY "Users can view their own profile"
    ON public.profiles FOR SELECT
    USING (auth_user_id = auth.uid() OR public.current_profile_role() IN ('supervisor', 'anm', 'asha'));

CREATE POLICY "Users can update their own profile"
    ON public.profiles FOR UPDATE
    USING (auth_user_id = auth.uid());

-- 2. Patients Policies
CREATE POLICY "Patients view own record"
    ON public.patients FOR SELECT
    USING (
        profile_id = public.current_profile_id()
        OR EXISTS (
            SELECT 1 FROM public.assignments 
            WHERE patient_id = patients.id 
            AND (asha_id = public.current_profile_id() OR anm_id = public.current_profile_id())
        )
        OR public.current_profile_role() = 'supervisor'
        OR EXISTS (
            SELECT 1 FROM public.caregiver_links 
            WHERE patient_id = patients.id 
            AND caregiver_profile_id = public.current_profile_id() 
            AND consent_given = true
        )
    );

-- 3. Medicine Logs Policies
CREATE POLICY "Patients write own medicine logs"
    ON public.medicine_logs FOR INSERT
    WITH CHECK (
        patient_id IN (SELECT id FROM public.patients WHERE profile_id = public.current_profile_id())
    );

CREATE POLICY "Allowed viewers read medicine logs"
    ON public.medicine_logs FOR SELECT
    USING (
        patient_id IN (SELECT id FROM public.patients WHERE profile_id = public.current_profile_id())
        OR EXISTS (
            SELECT 1 FROM public.assignments 
            WHERE patient_id = medicine_logs.patient_id 
            AND (asha_id = public.current_profile_id() OR anm_id = public.current_profile_id())
        )
        OR public.current_profile_role() = 'supervisor'
        OR EXISTS (
            SELECT 1 FROM public.caregiver_links 
            WHERE patient_id = medicine_logs.patient_id 
            AND caregiver_profile_id = public.current_profile_id() 
            AND consent_given = true
        )
    );

-- 4. Visits Policies
CREATE POLICY "Health workers log visits"
    ON public.visits FOR INSERT
    WITH CHECK (
        recorded_by = public.current_profile_id()
    );

CREATE POLICY "View visits"
    ON public.visits FOR SELECT
    USING (
        patient_id IN (SELECT id FROM public.patients WHERE profile_id = public.current_profile_id())
        OR EXISTS (
            SELECT 1 FROM public.assignments 
            WHERE patient_id = visits.patient_id 
            AND (asha_id = public.current_profile_id() OR anm_id = public.current_profile_id())
        )
        OR public.current_profile_role() = 'supervisor'
    );

-- 5. Alerts Policies
CREATE POLICY "View alerts"
    ON public.alerts FOR SELECT
    USING (
        assigned_to = public.current_profile_id()
        OR patient_id IN (SELECT id FROM public.patients WHERE profile_id = public.current_profile_id())
        OR public.current_profile_role() IN ('anm', 'supervisor')
    );

CREATE POLICY "Manage alerts"
    ON public.alerts FOR UPDATE
    USING (
        assigned_to = public.current_profile_id()
        OR public.current_profile_role() IN ('anm', 'supervisor')
    );

-- 6. Escalations Policies
CREATE POLICY "View escalations"
    ON public.escalations FOR SELECT
    USING (
        escalated_by = public.current_profile_id()
        OR escalated_to = public.current_profile_id()
        OR public.current_profile_role() = 'supervisor'
    );

CREATE POLICY "Create escalations"
    ON public.escalations FOR INSERT
    WITH CHECK (
        escalated_by = public.current_profile_id()
    );

CREATE POLICY "Decide escalations"
    ON public.escalations FOR UPDATE
    USING (
        escalated_to = public.current_profile_id()
        OR public.current_profile_role() = 'supervisor'
    );

-- ============================================================================
-- POLICIES REQUIRED BY THE APP'S OFFLINE OUTBOX (v3)
-- The outbox replays writes as idempotent UPSERTs, which need INSERT and
-- UPDATE permission. Without these, mothers' danger-sign alerts and SOS
-- events are rejected by RLS.
-- ============================================================================

-- Mothers raise alerts for themselves; health workers raise alerts for anyone.
CREATE POLICY "Create alerts"
    ON public.alerts FOR INSERT
    WITH CHECK (
        patient_id IN (SELECT id FROM public.patients WHERE profile_id = public.current_profile_id())
        OR public.current_profile_role() IN ('asha', 'anm', 'supervisor')
    );

CREATE POLICY "Patients update own medicine logs"
    ON public.medicine_logs FOR UPDATE
    USING (
        patient_id IN (SELECT id FROM public.patients WHERE profile_id = public.current_profile_id())
    );

CREATE POLICY "Health workers update own visits"
    ON public.visits FOR UPDATE
    USING (recorded_by = public.current_profile_id());

CREATE POLICY "Escalator updates own escalation"
    ON public.escalations FOR UPDATE
    USING (escalated_by = public.current_profile_id());

CREATE POLICY "ANM confirms HRP"
    ON public.patients FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.assignments
            WHERE patient_id = patients.id AND anm_id = public.current_profile_id()
        )
        OR public.current_profile_role() = 'supervisor'
    );

-- SOS events
CREATE POLICY "Patients raise SOS"
    ON public.sos_events FOR INSERT
    WITH CHECK (
        patient_id IN (SELECT id FROM public.patients WHERE profile_id = public.current_profile_id())
    );

CREATE POLICY "View SOS"
    ON public.sos_events FOR SELECT
    USING (
        patient_id IN (SELECT id FROM public.patients WHERE profile_id = public.current_profile_id())
        OR EXISTS (
            SELECT 1 FROM public.assignments
            WHERE patient_id = sos_events.patient_id
            AND (asha_id = public.current_profile_id() OR anm_id = public.current_profile_id())
        )
        OR public.current_profile_role() = 'supervisor'
    );

CREATE POLICY "Health workers respond to SOS"
    ON public.sos_events FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.assignments
            WHERE patient_id = sos_events.patient_id
            AND (asha_id = public.current_profile_id() OR anm_id = public.current_profile_id())
        )
        OR public.current_profile_role() = 'supervisor'
    );

-- Care team contacts for the signed-in mother (used by the SOS screen).
-- RLS hides other profiles from mothers, so expose only name/phone/role of
-- her actively assigned ASHA and ANM.
CREATE OR REPLACE FUNCTION public.get_my_care_team()
RETURNS TABLE (role TEXT, name TEXT, phone TEXT) AS $$
    SELECT pr.role, pr.name, pr.phone
    FROM public.patients p
    JOIN public.assignments a ON a.patient_id = p.id AND a.is_active
    JOIN public.profiles pr ON pr.id IN (a.asha_id, a.anm_id)
    WHERE p.profile_id = public.current_profile_id();
$$ LANGUAGE SQL STABLE SECURITY DEFINER SET search_path = public;

REVOKE ALL ON FUNCTION public.get_my_care_team() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_my_care_team() TO authenticated;
