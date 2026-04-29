do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'workout_records'
  ) and not exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'records'
  ) then
    alter table public.workout_records rename to records;
  end if;
end $$;

alter table public.records
add column if not exists session_id uuid;

update public.records as wr
set session_id = ws.id
from public.workout_sessions as ws
where wr.session_id is null
  and ws.user_id = wr.user_id
  and (ws.date at time zone 'UTC')::date = wr.session_date
  and ws.title = wr.title
  and ws.status = wr.status
  and ws.duration_minutes = wr.duration_minutes
  and coalesce(ws.notes, '') = coalesce(wr.notes, '');

do $$
begin
  if exists (
    select 1
    from public.records
    where session_id is null
  ) then
    raise exception 'records.session_id 回填失败，存在无法匹配到 workout_sessions 的历史快照';
  end if;
end $$;

alter table public.records
alter column session_id set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'fk_records_session'
  ) then
    alter table public.records
    add constraint fk_records_session
    foreign key (session_id, user_id)
    references public.workout_sessions (id, user_id)
    on delete cascade;
  end if;
end $$;

create index if not exists idx_records_user_session_created
on public.records using btree (user_id, session_id, created_at desc);

create index if not exists idx_records_session_created
on public.records using btree (session_id, created_at desc);

drop trigger if exists trg_block_completed_session_update on public.workout_sessions;
