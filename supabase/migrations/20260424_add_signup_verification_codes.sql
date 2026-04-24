create extension if not exists pgcrypto;

create table if not exists public.signup_verification_codes (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  code_hash text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now(),
  last_sent_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  send_count integer not null default 1,
  request_fingerprint text
);

create unique index if not exists signup_verification_codes_email_unique_idx
  on public.signup_verification_codes (lower(email));

create index if not exists signup_verification_codes_expires_at_idx
  on public.signup_verification_codes (expires_at);

alter table public.signup_verification_codes enable row level security;

drop policy if exists "signup_verification_codes_no_access" on public.signup_verification_codes;

create policy "signup_verification_codes_no_access"
on public.signup_verification_codes
for all
using (false)
with check (false);

drop trigger if exists touch_signup_verification_codes_updated_at_trigger on public.signup_verification_codes;

create trigger touch_signup_verification_codes_updated_at_trigger
before update on public.signup_verification_codes
for each row
execute function public.touch_updated_at();
