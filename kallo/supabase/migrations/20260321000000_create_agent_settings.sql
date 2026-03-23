-- Agent settings table — one row per company
create table if not exists public.agent_settings (
  id                          uuid primary key default gen_random_uuid(),
  company_id                  uuid not null unique references public.companies(id) on delete cascade,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now(),

  -- Identity
  business_name               text not null default '',
  agent_name                  text not null default 'Alex',
  business_description        text not null default '',
  business_hours              text not null default 'Mon–Fri 9am–5pm',
  language                    text not null default 'English (AU)',
  persona                     text not null default 'Professional',
  custom_instructions         text not null default '',
  greeting                    text not null default 'Hello, thank you for calling {business_name}. How can I help you today?',
  announce_ai_disclosure      boolean not null default true,

  -- Call Qualification
  qualification_questions     jsonb not null default '[]'::jsonb,
  default_destination         text not null default 'Take a message',
  default_transfer_number     text,

  -- Routing & Escalation
  transfer_on_human_request   boolean not null default true,
  transfer_on_repeat          boolean not null default true,
  transfer_on_failed_attempts boolean not null default true,
  transfer_on_duration_exceeded boolean not null default false,
  max_duration_minutes        integer not null default 10,
  escalation_transfer_number  text,
  out_of_hours_behaviour      text not null default 'Take a message and email to team',
  out_of_hours_message        text not null default '',
  emergency_override          boolean not null default false,
  emergency_transfer_number   text,
  voicemail_email             text,
  voicemail_sms               text,
  include_transcript_in_email boolean not null default true,

  -- Keywords
  termination_keywords        jsonb not null default '["bomb","threat","kill"]'::jsonb,
  termination_action          text not null default 'End call immediately, log incident',
  escalation_keywords         jsonb not null default '["urgent","emergency","complaint","manager"]'::jsonb,
  keyword_escalation_number   text,
  priority_keywords           jsonb not null default '["VIP","existing client"]'::jsonb,
  off_limits_keywords         jsonb not null default '["pricing","competitors","legal disputes"]'::jsonb,
  deflection_message          text not null default '',

  -- Behaviour
  max_response_length         text not null default 'Medium (2–4 sentences)',
  speaking_pace               text not null default 'Normal',
  use_filler_words            boolean not null default true,
  confirm_caller_details      boolean not null default true,
  ask_callback_if_busy        boolean not null default false,
  silence_timeout             integer not null default 8,
  silence_action              text not null default 'Prompt caller to respond',
  silence_prompt              text not null default 'Sorry, I didn''t catch that — are you still there?',
  allow_barge_in              boolean not null default true,
  record_calls                boolean not null default true,
  generate_transcript         boolean not null default false,
  generate_ai_summary         boolean not null default false,
  announce_recording          boolean not null default true,

  -- Telnyx
  telnyx_assistant_id         text
);

-- Auto-update updated_at
create trigger agent_settings_updated_at
  before update on public.agent_settings
  for each row execute function public.touch_updated_at();

-- RLS
alter table public.agent_settings enable row level security;

-- Admins can read/write their own company's settings
create policy "company admins can manage agent_settings"
  on public.agent_settings
  for all
  using (
    company_id = (
      select company_id from public.users
      where id = auth.uid()
    )
  )
  with check (
    company_id = (
      select company_id from public.users
      where id = auth.uid()
    )
  );
