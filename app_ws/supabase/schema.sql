-- Enable extensions required for UUID generation
create extension if not exists "pgcrypto";

-- Tear down legacy objects from the previous schema
drop table if exists public.session_medical_history cascade;
drop table if exists public.reports cascade;
drop table if exists public.vitals cascade;
drop table if exists public.patient_info cascade;

-- Core EMS session representing a single encounter
create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  incident_date date not null,
  arrival_at timestamptz,
  incident_address text not null,
  incident_type text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists sessions_user_incident_idx
  on public.sessions (user_id, incident_date desc);

alter table public.sessions enable row level security;

create policy "sessions_select" on public.sessions
  for select using (auth.uid() = user_id);

create policy "sessions_insert" on public.sessions
  for insert with check (auth.uid() = user_id);

create policy "sessions_update" on public.sessions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "sessions_delete" on public.sessions
  for delete using (auth.uid() = user_id);

-- One-to-one patient details captured for each session
create table if not exists public.session_patient_info (
  session_id uuid primary key references public.sessions(id) on delete cascade,
  patient_name text not null,
  date_of_birth date not null,
  sex char(1) not null check (sex in ('M', 'F', 'O', 'U')),
  height_in_inches smallint not null check (height_in_inches > 0),
  weight_in_pounds smallint not null check (weight_in_pounds > 0),
  allergies text,
  medications text,
  medical_history text not null default '',
  chief_complaint text not null,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.session_patient_info enable row level security;

create policy "session_patient_info_select" on public.session_patient_info
  for select using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_patient_info.session_id
        and s.user_id = auth.uid()
    )
  );

create policy "session_patient_info_insert" on public.session_patient_info
  for insert with check (
    exists (
      select 1
      from public.sessions s
      where s.id = session_patient_info.session_id
        and s.user_id = auth.uid()
    )
  );

create policy "session_patient_info_update" on public.session_patient_info
  for update using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_patient_info.session_id
        and s.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1
      from public.sessions s
      where s.id = session_patient_info.session_id
        and s.user_id = auth.uid()
    )
  );

create policy "session_patient_info_delete" on public.session_patient_info
  for delete using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_patient_info.session_id
        and s.user_id = auth.uid()
    )
  );

-- Multiple vitals snapshots per session
create table if not exists public.session_vitals (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions(id) on delete cascade,
  pulse_rate smallint not null check (pulse_rate >= 0),
  breathing_rate smallint not null check (breathing_rate >= 0),
  blood_pressure_systolic smallint not null check (blood_pressure_systolic > 0),
  blood_pressure_diastolic smallint not null check (blood_pressure_diastolic > 0),
  spo2 smallint check (spo2 between 0 and 100),
  blood_glucose smallint,
  temperature smallint,
  notes text,
  recorded_at timestamptz not null default timezone('utc', now())
);

create index if not exists session_vitals_session_idx
  on public.session_vitals (session_id, recorded_at desc);

alter table public.session_vitals enable row level security;

create policy "session_vitals_select" on public.session_vitals
  for select using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_vitals.session_id
        and s.user_id = auth.uid()
    )
  );

create policy "session_vitals_insert" on public.session_vitals
  for insert with check (
    exists (
      select 1
      from public.sessions s
      where s.id = session_vitals.session_id
        and s.user_id = auth.uid()
    )
  );

create policy "session_vitals_update" on public.session_vitals
  for update using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_vitals.session_id
        and s.user_id = auth.uid()
    )
  ) with check (
    exists (
      select 1
      from public.sessions s
      where s.id = session_vitals.session_id
        and s.user_id = auth.uid()
    )
  );

create policy "session_vitals_delete" on public.session_vitals
  for delete using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_vitals.session_id
        and s.user_id = auth.uid()
    )
  );
