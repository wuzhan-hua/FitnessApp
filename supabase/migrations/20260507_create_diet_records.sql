create table if not exists public.diet_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  consumed_at timestamptz not null,
  meal_type text not null,
  food_code text not null,
  food_name text not null,
  food_category text,
  grams numeric(10,2) not null,
  energy_kcal numeric(10,2) not null,
  protein numeric(10,2) not null,
  fat numeric(10,2) not null,
  carb numeric(10,2) not null,
  dietary_fiber numeric(10,2),
  cholesterol numeric(10,2),
  sodium numeric(10,2),
  constraint diet_records_grams_check check (grams > 0),
  constraint diet_records_meal_type_check check (
    meal_type in ('breakfast', 'lunch', 'dinner', 'snack')
  ),
  constraint diet_records_food_code_check check (btrim(food_code) <> ''),
  constraint diet_records_food_name_check check (btrim(food_name) <> '')
);

create index if not exists diet_records_user_consumed_at_idx
  on public.diet_records (user_id, consumed_at desc);

create index if not exists diet_records_user_meal_type_idx
  on public.diet_records (user_id, meal_type);

alter table public.diet_records enable row level security;

drop policy if exists "diet_records_select_own" on public.diet_records;
create policy "diet_records_select_own"
on public.diet_records
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "diet_records_insert_own" on public.diet_records;
create policy "diet_records_insert_own"
on public.diet_records
for insert
to authenticated
with check (auth.uid() = user_id);

grant select, insert on public.diet_records to authenticated;
