create table if not exists public.exercise_catalog_items (
  id text primary key,
  name_en text not null,
  name_zh text,
  equipment_en text,
  equipment_zh text,
  category_en text,
  category_zh text,
  force_en text,
  mechanic_en text,
  level_en text,
  primary_muscles_en text[] not null default '{}',
  primary_muscles_zh text[] not null default '{}',
  secondary_muscles_en text[] not null default '{}',
  secondary_muscles_zh text[] not null default '{}',
  instructions_en text[] not null default '{}',
  instructions_zh text[] not null default '{}',
  image_paths text[] not null default '{}',
  cover_image_path text,
  source text not null default 'free-exercise-db',
  source_version text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists exercise_catalog_items_source_idx
  on public.exercise_catalog_items (source, is_active);

create index if not exists exercise_catalog_items_category_en_idx
  on public.exercise_catalog_items (category_en);

create index if not exists exercise_catalog_items_equipment_en_idx
  on public.exercise_catalog_items (equipment_en);

create index if not exists exercise_catalog_items_primary_muscles_en_gin_idx
  on public.exercise_catalog_items
  using gin (primary_muscles_en);

create index if not exists exercise_catalog_items_primary_muscles_zh_gin_idx
  on public.exercise_catalog_items
  using gin (primary_muscles_zh);

alter table public.exercise_catalog_items enable row level security;

drop policy if exists "exercise_catalog_items_select_authenticated" on public.exercise_catalog_items;
create policy "exercise_catalog_items_select_authenticated"
on public.exercise_catalog_items
for select
to authenticated
using (is_active = true);

grant select on public.exercise_catalog_items to authenticated;

drop trigger if exists touch_exercise_catalog_items_updated_at_trigger on public.exercise_catalog_items;
create trigger touch_exercise_catalog_items_updated_at_trigger
before update on public.exercise_catalog_items
for each row
execute function public.touch_updated_at();

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'exercise-reference',
  'exercise-reference',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "exercise_reference_public_read" on storage.objects;
create policy "exercise_reference_public_read"
on storage.objects
for select
to public
using (bucket_id = 'exercise-reference');
