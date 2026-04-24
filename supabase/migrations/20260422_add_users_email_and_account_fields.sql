-- Add account-related fields to public.users and keep them synced from auth.users.

alter table public.users
  add column if not exists email text,
  add column if not exists email_verified_at timestamptz,
  add column if not exists phone text,
  add column if not exists last_sign_in_at timestamptz,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists is_profile_completed boolean not null default false;

create unique index if not exists users_email_unique_idx
  on public.users (lower(email))
  where email is not null;

create index if not exists users_last_sign_in_idx
  on public.users (last_sign_in_at desc);

create or replace function public.sync_public_users_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (
    user_id,
    email,
    email_verified_at,
    phone,
    last_sign_in_at,
    updated_at
  )
  values (
    new.id,
    new.email,
    new.email_confirmed_at,
    new.phone,
    new.last_sign_in_at,
    now()
  )
  on conflict (user_id) do update
    set email = excluded.email,
        email_verified_at = excluded.email_verified_at,
        phone = excluded.phone,
        last_sign_in_at = excluded.last_sign_in_at,
        updated_at = now();

  return new;
end;
$$;

drop trigger if exists sync_public_users_from_auth_trigger on auth.users;

create trigger sync_public_users_from_auth_trigger
after insert or update of email, phone, email_confirmed_at, last_sign_in_at
on auth.users
for each row
execute function public.sync_public_users_from_auth();

update public.users u
set email = a.email,
    email_verified_at = a.email_confirmed_at,
    phone = a.phone,
    last_sign_in_at = a.last_sign_in_at,
    updated_at = now()
from auth.users a
where u.user_id = a.id;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists touch_public_users_updated_at_trigger on public.users;

create trigger touch_public_users_updated_at_trigger
before update on public.users
for each row
execute function public.touch_updated_at();
