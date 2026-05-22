create or replace function public.block_workout_records_mutation()
returns trigger
language plpgsql
as $$
begin
  if current_setting('app.account_deletion', true) = 'true' then
    if tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  raise exception 'records 为历史快照，只允许新增，不允许修改或删除';
end;
$$;

create or replace function public.block_completed_session_mutation()
returns trigger
language plpgsql
as $$
begin
  if current_setting('app.account_deletion', true) = 'true' then
    return old;
  end if;

  if old.status = 'completed' then
    raise exception '已完成训练不可删除';
  end if;

  return old;
end;
$$;

create or replace function public.delete_account_data(target_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if target_user_id is null then
    raise exception 'target_user_id 不能为空';
  end if;

  perform set_config('app.account_deletion', 'true', true);

  delete from public.diet_records
  where user_id = target_user_id;

  delete from public.records
  where user_id = target_user_id;

  delete from public.workout_sessions
  where user_id = target_user_id;

  delete from public.user_profiles
  where user_id = target_user_id;

  delete from public.users
  where user_id = target_user_id;
end;
$$;

revoke all on function public.delete_account_data(uuid) from public;
grant execute on function public.delete_account_data(uuid) to service_role;
