alter table public.users
  add column if not exists is_admin boolean not null default false;

alter table public.users enable row level security;

drop policy if exists "users_select_own" on public.users;
create policy "users_select_own"
on public.users
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own"
on public.users
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own"
on public.users
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

grant select, insert, update on public.users to authenticated;

alter table public.exercise_catalog_items
  add column if not exists custom_name_zh text;

drop policy if exists "exercise_catalog_items_update_admin" on public.exercise_catalog_items;
create policy "exercise_catalog_items_update_admin"
on public.exercise_catalog_items
for update
to authenticated
using (
  exists (
    select 1
    from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
)
with check (
  exists (
    select 1
    from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
);

create table if not exists public.exercise_catalog_item_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_id text not null references public.exercise_catalog_items(id) on delete cascade,
  muscle_group text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint exercise_catalog_item_orders_exercise_group_unique unique (exercise_id, muscle_group),
  constraint exercise_catalog_item_orders_sort_order_check check (sort_order >= 0),
  constraint exercise_catalog_item_orders_muscle_group_check check (btrim(muscle_group) <> '')
);

create index if not exists exercise_catalog_item_orders_muscle_group_idx
  on public.exercise_catalog_item_orders (muscle_group, sort_order);

create index if not exists exercise_catalog_item_orders_user_id_idx
  on public.exercise_catalog_item_orders (user_id);

drop trigger if exists touch_exercise_catalog_item_orders_updated_at_trigger on public.exercise_catalog_item_orders;
create trigger touch_exercise_catalog_item_orders_updated_at_trigger
before update on public.exercise_catalog_item_orders
for each row
execute function public.touch_updated_at();

alter table public.exercise_catalog_item_orders enable row level security;

drop policy if exists "exercise_catalog_item_orders_select_authenticated" on public.exercise_catalog_item_orders;
create policy "exercise_catalog_item_orders_select_authenticated"
on public.exercise_catalog_item_orders
for select
to authenticated
using (true);

drop policy if exists "exercise_catalog_item_orders_insert_admin" on public.exercise_catalog_item_orders;
create policy "exercise_catalog_item_orders_insert_admin"
on public.exercise_catalog_item_orders
for insert
to authenticated
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
);

drop policy if exists "exercise_catalog_item_orders_update_admin" on public.exercise_catalog_item_orders;
create policy "exercise_catalog_item_orders_update_admin"
on public.exercise_catalog_item_orders
for update
to authenticated
using (
  auth.uid() = user_id
  and exists (
    select 1
    from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
)
with check (
  auth.uid() = user_id
  and exists (
    select 1
    from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
);

drop policy if exists "exercise_catalog_item_orders_delete_admin" on public.exercise_catalog_item_orders;
create policy "exercise_catalog_item_orders_delete_admin"
on public.exercise_catalog_item_orders
for delete
to authenticated
using (
  auth.uid() = user_id
  and exists (
    select 1
    from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
);

grant select, insert, update, delete on public.exercise_catalog_item_orders to authenticated;
