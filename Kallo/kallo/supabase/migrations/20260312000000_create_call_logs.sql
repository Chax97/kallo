create table if not exists call_logs (
  id                uuid        primary key default gen_random_uuid(),
  call_control_id   text        unique not null,
  call_leg_id       text,
  call_session_id   text,
  direction         text,        -- 'inbound' | 'outbound'
  from_number       text,
  to_number         text,
  state             text,        -- 'initiated' | 'answered' | 'completed' | 'missed'
  started_at        timestamptz,
  answered_at       timestamptz,
  ended_at          timestamptz,
  hangup_cause      text,
  duration_seconds  integer,
  recording_url     text,
  created_at        timestamptz default now()
);

alter table call_logs enable row level security;

-- Only the service role (Edge Functions) can read/write
create policy "service role full access" on call_logs
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');
