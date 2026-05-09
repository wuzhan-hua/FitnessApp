create table if not exists public.food_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_categories_name_unique unique (name),
  constraint food_categories_name_check check (btrim(name) <> ''),
  constraint food_categories_sort_order_check check (sort_order >= 0)
);

create index if not exists food_categories_active_order_idx
  on public.food_categories (is_active, sort_order, name);

drop trigger if exists touch_food_categories_updated_at_trigger on public.food_categories;
create trigger touch_food_categories_updated_at_trigger
before update on public.food_categories
for each row
execute function public.touch_updated_at();

create table if not exists public.food_catalog_items (
  id uuid primary key default gen_random_uuid(),
  food_code text not null,
  food_name text not null,
  category_id uuid not null references public.food_categories(id),
  edible numeric(10,2) not null default 100,
  water numeric(10,2) not null default 0,
  energy_kcal numeric(10,2) not null default 0,
  energy_kj numeric(10,2) not null default 0,
  protein numeric(10,2) not null default 0,
  fat numeric(10,2) not null default 0,
  carb numeric(10,2) not null default 0,
  dietary_fiber numeric(10,2) not null default 0,
  cholesterol numeric(10,2) not null default 0,
  ash numeric(10,2) not null default 0,
  vitamin_a numeric(10,2) not null default 0,
  carotene numeric(10,2) not null default 0,
  retinol numeric(10,2) not null default 0,
  thiamin numeric(10,2) not null default 0,
  riboflavin numeric(10,2) not null default 0,
  niacin numeric(10,2) not null default 0,
  vitamin_c numeric(10,2) not null default 0,
  vitamin_e_total numeric(10,2) not null default 0,
  vitamin_e1 numeric(10,2) not null default 0,
  vitamin_e2 numeric(10,2) not null default 0,
  vitamin_e3 numeric(10,2) not null default 0,
  calcium numeric(10,2) not null default 0,
  phosphorus numeric(10,2) not null default 0,
  potassium numeric(10,2) not null default 0,
  sodium numeric(10,2) not null default 0,
  magnesium numeric(10,2) not null default 0,
  iron numeric(10,2) not null default 0,
  zinc numeric(10,2) not null default 0,
  selenium numeric(10,2) not null default 0,
  copper numeric(10,2) not null default 0,
  manganese numeric(10,2) not null default 0,
  remark text,
  search_keywords text not null default '',
  sort_order integer not null default 0,
  source text not null default 'china-food-composition',
  is_active boolean not null default true,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_catalog_items_food_code_unique unique (food_code),
  constraint food_catalog_items_food_code_check check (btrim(food_code) <> ''),
  constraint food_catalog_items_food_name_check check (btrim(food_name) <> ''),
  constraint food_catalog_items_sort_order_check check (sort_order >= 0)
);

create index if not exists food_catalog_items_active_category_order_idx
  on public.food_catalog_items (is_active, category_id, sort_order, food_name);

create index if not exists food_catalog_items_food_name_idx
  on public.food_catalog_items (food_name);

create index if not exists food_catalog_items_created_by_idx
  on public.food_catalog_items (created_by);

drop trigger if exists touch_food_catalog_items_updated_at_trigger on public.food_catalog_items;
create trigger touch_food_catalog_items_updated_at_trigger
before update on public.food_catalog_items
for each row
execute function public.touch_updated_at();

alter table public.food_categories enable row level security;
alter table public.food_catalog_items enable row level security;

drop policy if exists "food_categories_select_active_authenticated" on public.food_categories;
create policy "food_categories_select_active_authenticated"
on public.food_categories
for select
to authenticated
using (is_active = true);

drop policy if exists "food_categories_select_admin" on public.food_categories;
create policy "food_categories_select_admin"
on public.food_categories
for select
to authenticated
using (
  exists (
    select 1 from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
);

drop policy if exists "food_categories_insert_admin" on public.food_categories;
create policy "food_categories_insert_admin"
on public.food_categories
for insert
to authenticated
with check (
  exists (
    select 1 from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
);

drop policy if exists "food_categories_update_admin" on public.food_categories;
create policy "food_categories_update_admin"
on public.food_categories
for update
to authenticated
using (
  exists (
    select 1 from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
)
with check (
  exists (
    select 1 from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
);

drop policy if exists "food_catalog_items_select_active_authenticated" on public.food_catalog_items;
create policy "food_catalog_items_select_active_authenticated"
on public.food_catalog_items
for select
to authenticated
using (is_active = true);

drop policy if exists "food_catalog_items_select_admin" on public.food_catalog_items;
create policy "food_catalog_items_select_admin"
on public.food_catalog_items
for select
to authenticated
using (
  exists (
    select 1 from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
);

drop policy if exists "food_catalog_items_insert_admin" on public.food_catalog_items;
create policy "food_catalog_items_insert_admin"
on public.food_catalog_items
for insert
to authenticated
with check (
  created_by = auth.uid()
  and exists (
    select 1 from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
);

drop policy if exists "food_catalog_items_update_admin" on public.food_catalog_items;
create policy "food_catalog_items_update_admin"
on public.food_catalog_items
for update
to authenticated
using (
  exists (
    select 1 from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
)
with check (
  exists (
    select 1 from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  )
);

grant select, insert, update on public.food_categories to authenticated;
grant select, insert, update on public.food_catalog_items to authenticated;
