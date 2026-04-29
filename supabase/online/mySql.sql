-- Database default timezone: Asia/Shanghai

create table public.signup_verification_codes (
  id uuid not null default gen_random_uuid (),
  email text not null,
  code_hash text not null,
  expires_at timestamp with time zone not null,
  consumed_at timestamp with time zone null,
  created_at timestamp with time zone not null default now(),
  last_sent_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  send_count integer not null default 1,
  request_fingerprint text null,
  purpose text not null default 'signup'::text,
  constraint signup_verification_codes_pkey primary key (id),
  constraint signup_verification_codes_purpose_check check (
    (
      purpose = any (array['signup'::text, 'guest_upgrade'::text])
    )
  )
) TABLESPACE pg_default;

create index IF not exists signup_verification_codes_expires_at_idx on public.signup_verification_codes using btree (expires_at) TABLESPACE pg_default;

create unique INDEX IF not exists signup_verification_codes_email_purpose_unique_idx on public.signup_verification_codes using btree (lower(email), purpose) TABLESPACE pg_default;

create trigger touch_signup_verification_codes_updated_at_trigger BEFORE
update on signup_verification_codes for EACH row
execute FUNCTION touch_updated_at ();



create table public.user_profiles (
  user_id uuid not null,
  profile_name text not null,
  gender text null,
  birth_date date null,
  height_cm numeric null,
  weight_kg numeric null,
  training_goal text null,
  training_years text null,
  activity_level text null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint user_profiles_pkey primary key (user_id),
  constraint user_profiles_user_id_fkey foreign KEY (user_id) references users (user_id)
) TABLESPACE pg_default;

create trigger touch_user_profiles_updated_at_trigger BEFORE
update on user_profiles for EACH row
execute FUNCTION touch_updated_at ();



create table public.users (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  created_at timestamp with time zone not null default now(),
  nickname text null,
  avatar_url text null,
  email text null,
  email_verified_at timestamp with time zone null,
  phone text null,
  last_sign_in_at timestamp with time zone null,
  updated_at timestamp with time zone not null default now(),
  is_profile_completed boolean not null default false,
  is_admin boolean not null default false,
  user_type smallint not null default 0,
  constraint users_pkey primary key (id),
  constraint users_user_id_key unique (user_id),
  constraint users_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint users_user_type_check check ((user_type = any (array[0, 1])))
) TABLESPACE pg_default;

create unique INDEX IF not exists users_email_unique_idx on public.users using btree (lower(email)) TABLESPACE pg_default
where
  (email is not null);

create index IF not exists users_last_sign_in_idx on public.users using btree (last_sign_in_at desc) TABLESPACE pg_default;

create trigger touch_public_users_updated_at_trigger BEFORE
update on users for EACH row
execute FUNCTION touch_updated_at ();



create table public.workout_exercises (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  created_at timestamp with time zone not null default now(),
  session_id uuid not null,
  exercise_id text not null,
  exercise_name text not null,
  target_sets integer not null default 0,
  sort_order integer not null default 0,
  constraint workout_exercises_pkey primary key (id),
  constraint workout_exercises_id_user_unique unique (id, user_id),
  constraint fk_workout_exercises_session foreign KEY (session_id, user_id) references workout_sessions (id, user_id) on delete CASCADE,
  constraint workout_exercises_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint workout_exercises_sort_order_check check ((sort_order >= 0)),
  constraint workout_exercises_target_sets_check check ((target_sets >= 0))
) TABLESPACE pg_default;

create index IF not exists idx_workout_exercises_user_session on public.workout_exercises using btree (user_id, session_id, sort_order) TABLESPACE pg_default;




create table public.records (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  created_at timestamp with time zone not null default now(),
  session_id uuid not null,
  session_date date not null,
  title text not null default ''::text,
  status text not null default 'draft'::text,
  duration_minutes integer not null default 0,
  exercises jsonb not null default '[]'::jsonb,
  notes text null,
  constraint records_pkey primary key (id),
  constraint fk_records_session foreign KEY (session_id, user_id) references workout_sessions (id, user_id) on delete CASCADE,
  constraint records_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE
) TABLESPACE pg_default;

create index IF not exists idx_records_user_id on public.records using btree (user_id) TABLESPACE pg_default;

create index IF not exists idx_records_session_date on public.records using btree (session_date) TABLESPACE pg_default;

create index IF not exists idx_records_created_at on public.records using btree (created_at desc) TABLESPACE pg_default;

create index IF not exists idx_records_user_created on public.records using btree (user_id, created_at desc) TABLESPACE pg_default;

create index IF not exists idx_records_user_session_created on public.records using btree (user_id, session_id, created_at desc) TABLESPACE pg_default;

create index IF not exists idx_records_session_created on public.records using btree (session_id, created_at desc) TABLESPACE pg_default;

create trigger trg_block_records_delete BEFORE DELETE on records for EACH row
execute FUNCTION block_workout_records_mutation ();

create trigger trg_block_records_update BEFORE
update on records for EACH row
execute FUNCTION block_workout_records_mutation ();





create table public.workout_sessions (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  created_at timestamp with time zone not null default now(),
  date timestamp with time zone not null,
  title text not null default ''::text,
  status text not null default 'draft'::text,
  duration_minutes integer not null default 0,
  notes text null,
  constraint workout_sessions_pkey primary key (id),
  constraint workout_sessions_id_user_unique unique (id, user_id),
  constraint workout_sessions_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint workout_sessions_duration_minutes_check check ((duration_minutes >= 0)),
  constraint workout_sessions_status_check check (
    (
      status = any (
        array[
          'draft'::text,
          'in_progress'::text,
          'completed'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_workout_sessions_user_date on public.workout_sessions using btree (user_id, date desc) TABLESPACE pg_default;

create trigger trg_block_completed_session_delete BEFORE DELETE on workout_sessions for EACH row
execute FUNCTION block_completed_session_mutation ();




create table public.workout_sets (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  created_at timestamp with time zone not null default now(),
  session_id uuid not null,
  exercise_row_id uuid not null,
  set_index integer not null,
  weight numeric(10, 2) not null default 0,
  reps integer not null default 0,
  rest_seconds integer not null default 0,
  is_completed boolean not null default false,
  set_type text not null default 'strength'::text,
  duration_minutes integer null,
  distance_km numeric(10, 3) null,
  constraint workout_sets_pkey primary key (id),
  constraint workout_sets_unique_exercise_set unique (exercise_row_id, set_index),
  constraint fk_workout_sets_session foreign KEY (session_id, user_id) references workout_sessions (id, user_id) on delete CASCADE,
  constraint workout_sets_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint fk_workout_sets_exercise foreign KEY (exercise_row_id, user_id) references workout_exercises (id, user_id) on delete CASCADE,
  constraint workout_sets_set_index_check check ((set_index > 0)),
  constraint workout_sets_set_type_check check (
    (
      set_type = any (array['strength'::text, 'cardio'::text])
    )
  ),
  constraint workout_sets_weight_check check ((weight >= (0)::numeric)),
  constraint workout_sets_distance_km_check check (
    (
      (distance_km is null)
      or (distance_km >= (0)::numeric)
    )
  ),
  constraint workout_sets_duration_minutes_check check (
    (
      (duration_minutes is null)
      or (duration_minutes >= 0)
    )
  ),
  constraint workout_sets_reps_check check ((reps >= 0)),
  constraint workout_sets_rest_seconds_check check ((rest_seconds >= 0))
) TABLESPACE pg_default;

create index IF not exists idx_workout_sets_user_session on public.workout_sets using btree (user_id, session_id) TABLESPACE pg_default;



create table public.exercise_catalog_items (
  id text not null,
  name_en text not null,
  name_zh text null,
  equipment_en text null,
  equipment_zh text null,
  category_en text null,
  category_zh text null,
  force_en text null,
  mechanic_en text null,
  level_en text null,
  primary_muscles_en text[] not null default '{}'::text[],
  primary_muscles_zh text[] not null default '{}'::text[],
  secondary_muscles_en text[] not null default '{}'::text[],
  secondary_muscles_zh text[] not null default '{}'::text[],
  instructions_en text[] not null default '{}'::text[],
  instructions_zh text[] not null default '{}'::text[],
  image_paths text[] not null default '{}'::text[],
  cover_image_path text null,
  source text not null default 'free-exercise-db'::text,
  source_version text null,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  custom_name_zh text null,
  constraint exercise_catalog_items_pkey primary key (id)
) TABLESPACE pg_default;

create index IF not exists exercise_catalog_items_source_idx on public.exercise_catalog_items using btree (source, is_active) TABLESPACE pg_default;

create index IF not exists exercise_catalog_items_category_en_idx on public.exercise_catalog_items using btree (category_en) TABLESPACE pg_default;

create index IF not exists exercise_catalog_items_equipment_en_idx on public.exercise_catalog_items using btree (equipment_en) TABLESPACE pg_default;

create index IF not exists exercise_catalog_items_primary_muscles_en_gin_idx on public.exercise_catalog_items using gin (primary_muscles_en) TABLESPACE pg_default;

create index IF not exists exercise_catalog_items_primary_muscles_zh_gin_idx on public.exercise_catalog_items using gin (primary_muscles_zh) TABLESPACE pg_default;

create trigger touch_exercise_catalog_items_updated_at_trigger BEFORE
update on exercise_catalog_items for EACH row
execute FUNCTION touch_updated_at ();



create table public.exercise_catalog_item_orders (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null,
  exercise_id text not null,
  muscle_group text not null,
  sort_order integer not null default 0,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint exercise_catalog_item_orders_pkey primary key (id),
  constraint exercise_catalog_item_orders_exercise_group_unique unique (exercise_id, muscle_group),
  constraint exercise_catalog_item_orders_user_id_fkey foreign KEY (user_id) references auth.users (id) on delete CASCADE,
  constraint exercise_catalog_item_orders_exercise_id_fkey foreign KEY (exercise_id) references exercise_catalog_items (id) on delete CASCADE,
  constraint exercise_catalog_item_orders_sort_order_check check ((sort_order >= 0)),
  constraint exercise_catalog_item_orders_muscle_group_check check ((btrim(muscle_group) <> ''::text))
) TABLESPACE pg_default;

create index IF not exists exercise_catalog_item_orders_muscle_group_idx on public.exercise_catalog_item_orders using btree (muscle_group, sort_order) TABLESPACE pg_default;

create index IF not exists exercise_catalog_item_orders_user_id_idx on public.exercise_catalog_item_orders using btree (user_id) TABLESPACE pg_default;

create trigger touch_exercise_catalog_item_orders_updated_at_trigger BEFORE
update on exercise_catalog_item_orders for EACH row
execute FUNCTION touch_updated_at ();
