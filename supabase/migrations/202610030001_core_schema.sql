create extension if not exists pgcrypto;

do $$ begin
  create type public.member_status as enum ('trialing', 'active', 'cancelled', 'expired');
exception when duplicate_object then null;
end $$;

create table if not exists public.members (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  status public.member_status not null default 'trialing',
  trial_ends_at timestamptz not null default (now() + interval '7 days'),
  paid_through timestamptz,
  payfast_token text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  pf_payment_id text not null unique,
  member_id uuid not null references public.members (id) on delete cascade,
  amount numeric(10, 2) not null check (amount >= 0),
  status text not null check (status in ('COMPLETE', 'FAILED', 'PENDING', 'CANCELLED')),
  raw jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.centres (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  region text not null check (length(trim(region)) > 0),
  address text,
  phone text,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180)
);

create index if not exists centres_region_idx on public.centres (region);
create index if not exists payments_member_created_idx on public.payments (member_id, created_at desc);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists members_set_updated_at on public.members;
create trigger members_set_updated_at
before update on public.members
for each row execute function public.set_updated_at();

-- Optional eager member creation. GET /api/me also performs an idempotent lazy insert.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.members (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

alter table public.members enable row level security;
alter table public.payments enable row level security;
alter table public.centres enable row level security;

-- Members are readable by their owner only. No client write policy is created.
revoke all on table public.members from anon, authenticated;
grant select on table public.members to authenticated;
grant all on table public.members to service_role;
drop policy if exists members_select_own on public.members;
create policy members_select_own on public.members
for select to authenticated
using ((select auth.uid()) = id);

-- Payment data and the directory are API-only (service role bypasses RLS).
revoke all on table public.payments from anon, authenticated;
grant all on table public.payments to service_role;
revoke all on table public.centres from anon, authenticated;
grant select, insert, update, delete on table public.centres to service_role;

-- One RPC atomically records the PayFast notification and applies its entitlement change.
create or replace function public.apply_payfast_itn(
  p_pf_payment_id text,
  p_member_id uuid,
  p_amount numeric,
  p_status text,
  p_raw jsonb,
  p_token text,
  p_trial_setup boolean,
  p_now timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  inserted_count integer;
begin
  if p_status not in ('COMPLETE', 'FAILED', 'PENDING', 'CANCELLED') then
    raise exception 'unsupported payment status';
  end if;
  if p_amount < 0 or (p_trial_setup and p_amount <> 0) then
    raise exception 'invalid payment amount';
  end if;

  insert into public.payments (pf_payment_id, member_id, amount, status, raw)
  values (p_pf_payment_id, p_member_id, p_amount, p_status, coalesce(p_raw, '{}'::jsonb))
  on conflict (pf_payment_id) do nothing;
  get diagnostics inserted_count = row_count;

  if inserted_count = 0 then
    return false;
  end if;

  if p_status = 'COMPLETE' then
    if p_trial_setup then
      update public.members
      set status = case
            when paid_through is not null and paid_through + interval '3 days' >= p_now then 'active'::public.member_status
            else 'trialing'::public.member_status
          end,
          payfast_token = coalesce(nullif(p_token, ''), payfast_token)
      where id = p_member_id;
    else
      update public.members
      set status = 'active'::public.member_status,
          paid_through = greatest(coalesce(paid_through, p_now), p_now) + interval '1 month',
          payfast_token = coalesce(nullif(p_token, ''), payfast_token)
      where id = p_member_id;
    end if;
  elsif p_status = 'CANCELLED' then
    update public.members
    set status = 'cancelled'::public.member_status,
        payfast_token = coalesce(nullif(p_token, ''), payfast_token)
    where id = p_member_id;
  end if;

  return true;
end;
$$;

revoke all on function public.apply_payfast_itn(text, uuid, numeric, text, jsonb, text, boolean, timestamptz) from public, anon, authenticated;
grant execute on function public.apply_payfast_itn(text, uuid, numeric, text, jsonb, text, boolean, timestamptz) to service_role;
