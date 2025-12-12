-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.patient_info (
  user_id uuid NOT NULL,
  name text NOT NULL,
  age smallint NOT NULL CHECK (age >= 0),
  chief_complaint text NOT NULL,
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  session_id uuid NOT NULL,
  CONSTRAINT patient_info_pkey PRIMARY KEY (session_id),
  CONSTRAINT patient_info_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT patient_info_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.session(session_id)
);
CREATE TABLE public.reports (
  user_id uuid NOT NULL,
  notes text,
  observations text,
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  session_id uuid NOT NULL,
  CONSTRAINT reports_pkey PRIMARY KEY (session_id),
  CONSTRAINT reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT reports_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.session(session_id)
);
CREATE TABLE public.session (
  session_id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  started_at timestamp with time zone NOT NULL DEFAULT now(),
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT session_pkey PRIMARY KEY (session_id),
  CONSTRAINT session_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.vitals (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  heart_rate smallint NOT NULL,
  blood_pressure text NOT NULL,
  respiratory_rate smallint NOT NULL,
  temperature numeric NOT NULL,
  recorded_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  session_id uuid NOT NULL,
  CONSTRAINT vitals_pkey PRIMARY KEY (id),
  CONSTRAINT vitals_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT vitals_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.session(session_id)
);
CREATE TABLE public.chart (
  user_id uuid NOT NULL,
  allergies text,
  medications text,
  family_history text,
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  session_id uuid NOT NULL,
  CONSTRAINT chart_pkey PRIMARY KEY (session_id),
  CONSTRAINT chart_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT chart_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.session(session_id)
);