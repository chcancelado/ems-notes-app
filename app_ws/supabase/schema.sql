-- Enable UUID extension
create extension if not exists "pgcrypto";

------------------------------------------------------------
-- AGENCIES
------------------------------------------------------------

create table public.agencies (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.agencies enable row level security;

create policy "agencies_authenticated"
  on public.agencies
  for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

------------------------------------------------------------
-- AGENCY MEMBERS
------------------------------------------------------------

create table public.agency_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  agency_id uuid not null references public.agencies(id) on delete cascade,
  member_email text not null,
  joined_at timestamptz not null default timezone('utc', now())
);

alter table public.agency_members enable row level security;

create policy "agency_members_self"
  on public.agency_members
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "agency_members_same_agency"
  on public.agency_members
  for select using (
    exists (
      select 1
      from public.agency_members am2
      where am2.user_id = auth.uid()
        and am2.agency_id = agency_members.agency_id
    )
  );

------------------------------------------------------------
-- SESSIONS (Core encounter)
------------------------------------------------------------

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  agency_id uuid not null references public.agencies(id) on delete cascade,
  incident_date date not null,
  arrival_at timestamptz,
  incident_address text not null,
  incident_type text not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index sessions_user_incident_idx
  on public.sessions (user_id, incident_date desc);

alter table public.sessions enable row level security;

------------------------------------------------------------
-- SESSION SHARES
------------------------------------------------------------

create table public.session_shares (
  session_id uuid not null references public.sessions(id) on delete cascade,
  shared_with_user_id uuid not null references auth.users(id) on delete cascade,
  shared_by_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (session_id, shared_with_user_id)
);

alter table public.session_shares enable row level security;

create policy "session_shares_select"
  on public.session_shares
  for select using (
    shared_with_user_id = auth.uid()
    or shared_by_user_id = auth.uid()
    or auth.role() = 'authenticated'
  );

create policy "session_shares_insert"
  on public.session_shares
  for insert with check (
    shared_by_user_id = auth.uid()
  );

create policy "session_shares_delete"
  on public.session_shares
  for delete using (
    shared_by_user_id = auth.uid()
    or shared_with_user_id = auth.uid()
  );

------------------------------------------------------------
-- SESSION POLICIES
------------------------------------------------------------

create policy "sessions_select"
  on public.sessions
  for select using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.session_shares sh
      where sh.session_id = sessions.id
        and sh.shared_with_user_id = auth.uid()
    )
  );

create policy "sessions_insert"
  on public.sessions
  for insert with check (
    auth.uid() = user_id
    and exists (
      select 1
      from public.agency_members am
      where am.user_id = auth.uid()
        and am.agency_id = sessions.agency_id
    )
  );

create policy "sessions_update"
  on public.sessions
  for update using (
    auth.uid() = user_id
    or exists (
      select 1
      from public.session_shares sh
      where sh.session_id = sessions.id
        and sh.shared_with_user_id = auth.uid()
    )
  )
  with check (
    auth.uid() = user_id
    or exists (
      select 1
      from public.session_shares sh
      where sh.session_id = sessions.id
        and sh.shared_with_user_id = auth.uid()
    )
  );

create policy "sessions_delete"
  on public.sessions
  for delete using (auth.uid() = user_id);

------------------------------------------------------------
-- PATIENT INFO
------------------------------------------------------------

create table public.session_patient_info (
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

create policy "spi_select"
  on public.session_patient_info
  for select using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_patient_info.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1
            from public.session_shares sh
            where sh.session_id = s.id
              and sh.shared_with_user_id = auth.uid()
          )
        )
    )
  );

create policy "spi_insert"
  on public.session_patient_info
  for insert with check (
    exists (
      select 1
      from public.sessions s
      where s.id = session_patient_info.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1
            from public.session_shares sh
            where sh.session_id = s.id
              and sh.shared_with_user_id = auth.uid()
          )
        )
    )
  );

create policy "spi_update"
  on public.session_patient_info
  for update using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_patient_info.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1
            from public.session_shares sh
            where sh.session_id = s.id
              and sh.shared_with_user_id = auth.uid()
          )
        )
    )
  )
  with check (
    exists (
      select 1
      from public.sessions s
      where s.id = session_patient_info.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1
            from public.session_shares sh
            where sh.session_id = s.id
              and sh.shared_with_user_id = auth.uid()
          )
        )
    )
  );

create policy "spi_delete"
  on public.session_patient_info
  for delete using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_patient_info.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1
            from public.session_shares sh
            where sh.session_id = s.id
              and sh.shared_with_user_id = auth.uid()
          )
        )
    )
  );

------------------------------------------------------------
-- VITALS
------------------------------------------------------------

create table public.session_vitals (
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
  recording_started_at timestamptz not null default timezone('utc', now()),
  recording_ended_at timestamptz not null default timezone('utc', now()),
  recorded_at timestamptz not null default timezone('utc', now())
);

create index session_vitals_session_idx
  on public.session_vitals (session_id, recorded_at desc);

alter table public.session_vitals enable row level security;

create policy "session_vitals_select"
  on public.session_vitals
  for select using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_vitals.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1
            from public.session_shares sh
            where sh.session_id = s.id
              and sh.shared_with_user_id = auth.uid()
          )
        )
    )
  );

create policy "session_vitals_insert"
  on public.session_vitals
  for insert with check (
    exists (
      select 1
      from public.sessions s
      where s.id = session_vitals.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1
            from public.session_shares sh
            where sh.session_id = s.id
              and sh.shared_with_user_id = auth.uid()
          )
        )
    )
  );

create policy "session_vitals_update"
  on public.session_vitals
  for update using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_vitals.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1
            from public.session_shares sh
            where sh.session_id = s.id
              and sh.shared_with_user_id = auth.uid()
          )
        )
    )
  )
  with check (
    exists (
      select 1
      from public.sessions s
      where s.id = session_vitals.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1
            from public.session_shares sh
            where sh.session_id = s.id
              and sh.shared_with_user_id = auth.uid()
          )
        )
    )
  );

create policy "session_vitals_delete"
  on public.session_vitals
  for delete using (
    exists (
      select 1
      from public.sessions s
      where s.id = session_vitals.session_id
        and (
          s.user_id = auth.uid()
          or exists (
            select 1
            from public.session_shares sh
            where sh.session_id = s.id
              and sh.shared_with_user_id = auth.uid()
          )
        )
    )
  );
