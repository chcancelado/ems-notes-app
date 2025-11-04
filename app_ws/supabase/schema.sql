-- ============================================================
-- Create and use new schema "updated_all"
-- ============================================================
CREATE SCHEMA IF NOT EXISTS updated_all;
SET search_path TO updated_all;

-- Enable extension for UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- Core EMS session representing a single encounter
-- ============================================================
CREATE TABLE IF NOT EXISTS updated_all.sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  incident_date date NOT NULL,
  arrival_at timestamptz,
  incident_address text NOT NULL,
  incident_type text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT timezone('utc', now()),
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS sessions_user_incident_idx
  ON updated_all.sessions (user_id, incident_date DESC);

ALTER TABLE updated_all.sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "sessions_select" ON updated_all.sessions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "sessions_insert" ON updated_all.sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "sessions_update" ON updated_all.sessions
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "sessions_delete" ON updated_all.sessions
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- Patient details captured for each session
--   (includes one free-text medical_history field)
-- ============================================================
CREATE TABLE IF NOT EXISTS updated_all.session_patient_info (
  session_id uuid PRIMARY KEY REFERENCES updated_all.sessions(id) ON DELETE CASCADE,
  patient_name text NOT NULL,
  date_of_birth date NOT NULL,
  sex char(1) NOT NULL CHECK (sex IN ('M','F','O','U')),
  height_in_inches smallint NOT NULL CHECK (height_in_inches > 0),
  weight_in_pounds smallint NOT NULL CHECK (weight_in_pounds > 0),
  allergies text,
  medications text,
  medical_history text,  -- merged field replacing separate table
  chief_complaint text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

ALTER TABLE updated_all.session_patient_info ENABLE ROW LEVEL SECURITY;

CREATE POLICY "session_patient_info_select" ON updated_all.session_patient_info
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM updated_all.sessions s
      WHERE s.id = session_patient_info.session_id
        AND s.user_id = auth.uid()
    )
  );

CREATE POLICY "session_patient_info_insert" ON updated_all.session_patient_info
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1
      FROM updated_all.sessions s
      WHERE s.id = session_patient_info.session_id
        AND s.user_id = auth.uid()
    )
  );

CREATE POLICY "session_patient_info_update" ON updated_all.session_patient_info
  FOR UPDATE USING (
    EXISTS (
      SELECT 1
      FROM updated_all.sessions s
      WHERE s.id = session_patient_info.session_id
        AND s.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM updated_all.sessions s
      WHERE s.id = session_patient_info.session_id
        AND s.user_id = auth.uid()
    )
  );

CREATE POLICY "session_patient_info_delete" ON updated_all.session_patient_info
  FOR DELETE USING (
    EXISTS (
      SELECT 1
      FROM updated_all.sessions s
      WHERE s.id = session_patient_info.session_id
        AND s.user_id = auth.uid()
    )
  );

-- ============================================================
-- Multiple vitals snapshots per session
-- ============================================================
CREATE TABLE IF NOT EXISTS updated_all.session_vitals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES updated_all.sessions(id) ON DELETE CASCADE,
  pulse_rate smallint NOT NULL CHECK (pulse_rate >= 0),
  breathing_rate smallint NOT NULL CHECK (breathing_rate >= 0),
  blood_pressure_systolic smallint NOT NULL CHECK (blood_pressure_systolic > 0),
  blood_pressure_diastolic smallint NOT NULL CHECK (blood_pressure_diastolic > 0),
  spo2 smallint CHECK (spo2 BETWEEN 0 AND 100),
  blood_glucose smallint,
  temperature smallint,
  notes text,
  recorded_at timestamptz NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS session_vitals_session_idx
  ON updated_all.session_vitals (session_id, recorded_at DESC);

ALTER TABLE updated_all.session_vitals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "session_vitals_select" ON updated_all.session_vitals
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM updated_all.sessions s
      WHERE s.id = session_vitals.session_id
        AND s.user_id = auth.uid()
    )
  );

CREATE POLICY "session_vitals_insert" ON updated_all.session_vitals
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1
      FROM updated_all.sessions s
      WHERE s.id = session_vitals.session_id
        AND s.user_id = auth.uid()
    )
  );

CREATE POLICY "session_vitals_update" ON updated_all.session_vitals
  FOR UPDATE USING (
    EXISTS (
      SELECT 1
      FROM updated_all.sessions s
      WHERE s.id = session_vitals.session_id
        AND s.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM updated_all.sessions s
      WHERE s.id = session_vitals.session_id
        AND s.user_id = auth.uid()
    )
  );

CREATE POLICY "session_vitals_delete" ON updated_all.session_vitals
  FOR DELETE USING (
    EXISTS (
      SELECT 1
      FROM updated_all.sessions s
      WHERE s.id = session_vitals.session_id
        AND s.user_id = auth.uid()
    )
  );
