create table if not exists public.user_profiles (
  user_id uuid primary key references public.users(user_id),
  profile_name text not null,
  gender text,
  birth_date date,
  height_cm numeric,
  weight_kg numeric,
  training_goal text,
  training_years text,
  activity_level text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists touch_user_profiles_updated_at_trigger on public.user_profiles;

create trigger touch_user_profiles_updated_at_trigger
before update on public.user_profiles
for each row
execute function public.touch_updated_at();

alter table public.user_profiles enable row level security;

drop policy if exists "user_profiles_select_own" on public.user_profiles;
create policy "user_profiles_select_own"
on public.user_profiles
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "user_profiles_insert_own" on public.user_profiles;
create policy "user_profiles_insert_own"
on public.user_profiles
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "user_profiles_update_own" on public.user_profiles;
create policy "user_profiles_update_own"
on public.user_profiles
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

grant select, insert, update on public.user_profiles to authenticated;
