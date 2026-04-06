create table if not exists calls (
  id                uuid        primary key default gen_random_uuid(),
  telnyx_call_id    text        unique,
  call_leg_id       text,
  call_session_id   text,
  direction         text,        -- 'inbound' | 'outbound'
  from_number       text,
  to_number         text,
  status            text,        -- 'initiated' | 'answered' | 'completed' | 'missed' | 'voicemail'
  state             text,
  started_at        timestamptz,
  answered_at       timestamptz,
  ended_at          timestamptz,
  hangup_cause      text,
  duration_seconds  integer,
  recording_url     text,
  storage_path      text,
  answered_by       text,        -- 'app' | 'ai_assistant'
  company_id        uuid,
  created_at        timestamptz default now()
);

-- Index for fast lookups by phone number (used in call log queries)
create index if not exists calls_from_number_idx on calls (from_number);
create index if not exists calls_to_number_idx on calls (to_number);
create index if not exists calls_started_at_idx on calls (started_at desc);
create index if not exists calls_company_id_idx on calls (company_id);

alter table calls enable row level security;

-- Service role (Edge Functions) can read/write everything
create policy "service role full access" on calls
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- Authenticated users can read calls for their company
create policy "authenticated read own company calls" on calls
  for select
  using (auth.role() = 'authenticated');
