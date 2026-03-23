-- AI agents table — multiple named agents per company
create table if not exists public.ai_agents (
  id          uuid primary key default gen_random_uuid(),
  company_id  uuid not null references public.companies(id) on delete cascade,
  name        text not null default 'New Agent',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists ai_agents_company_id_idx on public.ai_agents(company_id);

-- Auto-update updated_at
create trigger ai_agents_updated_at
  before update on public.ai_agents
  for each row execute function public.touch_updated_at();

-- RLS
alter table public.ai_agents enable row level security;

create policy "company admins can manage ai_agents"
  on public.ai_agents
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
