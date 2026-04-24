create extension if not exists pgcrypto;

alter table public.users
  add column if not exists user_type smallint not null default 0,
  add column if not exists password_hash text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'users_user_type_check'
      and conrelid = 'public.users'::regclass
  ) then
    alter table public.users
      add constraint users_user_type_check
      check (user_type in (0, 1));
  end if;
end
$$;

update public.users
set user_type = case
  when email is not null then 1
  else 0
end
where user_type not in (0, 1)
   or (email is not null and user_type <> 1)
   or (email is null and user_type <> 0);

create or replace function public.hash_user_password(raw_password text)
returns text
language plpgsql
security definer
set search_path = public
as $$
begin
  if raw_password is null or btrim(raw_password) = '' then
    raise exception '密码不能为空';
  end if;

  return crypt(raw_password, gen_salt('bf'));
end;
$$;

create or replace function public.verify_user_password(
  raw_password text,
  stored_hash text
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if raw_password is null or stored_hash is null then
    return false;
  end if;

  return crypt(raw_password, stored_hash) = stored_hash;
end;
$$;

create or replace function public.set_current_user_password_hash(raw_password text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception '未登录，无法设置密码';
  end if;

  update public.users
  set password_hash = public.hash_user_password(raw_password),
      user_type = 1,
      updated_at = now()
  where user_id = current_user_id;

  if not found then
    raise exception '未找到对应用户资料';
  end if;
end;
$$;

create or replace function public.complete_current_user_email_registration(
  account_email text,
  raw_password text,
  account_type smallint default 1
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_user_id uuid := auth.uid();
  auth_user auth.users%rowtype;
begin
  if current_user_id is null then
    raise exception '未登录，无法完成邮箱注册';
  end if;

  if account_type <> 1 then
    raise exception '仅支持邮箱账号类型';
  end if;

  select *
  into auth_user
  from auth.users
  where id = current_user_id;

  if not found then
    raise exception '未找到认证用户';
  end if;

  insert into public.users (
    user_id,
    email,
    email_verified_at,
    phone,
    last_sign_in_at,
    user_type,
    password_hash,
    updated_at
  )
  values (
    current_user_id,
    account_email,
    auth_user.email_confirmed_at,
    auth_user.phone,
    auth_user.last_sign_in_at,
    account_type,
    public.hash_user_password(raw_password),
    now()
  )
  on conflict (user_id) do update
    set email = excluded.email,
        email_verified_at = excluded.email_verified_at,
        phone = excluded.phone,
        last_sign_in_at = excluded.last_sign_in_at,
        user_type = excluded.user_type,
        password_hash = excluded.password_hash,
        updated_at = now();
end;
$$;

create or replace function public.verify_user_login(
  login_email text,
  raw_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  target_user public.users%rowtype;
begin
  select *
  into target_user
  from public.users
  where lower(email) = lower(login_email)
  limit 1;

  if not found then
    return jsonb_build_object(
      'is_valid', false,
      'error_code', 'account_not_found'
    );
  end if;

  if target_user.user_type <> 1 then
    return jsonb_build_object(
      'is_valid', false,
      'error_code', 'account_type_mismatch'
    );
  end if;

  if target_user.password_hash is null then
    return jsonb_build_object(
      'is_valid', false,
      'error_code', 'password_not_set'
    );
  end if;

  if not public.verify_user_password(raw_password, target_user.password_hash) then
    return jsonb_build_object(
      'is_valid', false,
      'error_code', 'invalid_password'
    );
  end if;

  return jsonb_build_object(
    'is_valid', true,
    'error_code', null,
    'user_id', target_user.user_id,
    'email', target_user.email,
    'user_type', target_user.user_type
  );
end;
$$;

revoke all on function public.hash_user_password(text) from public;
revoke all on function public.verify_user_password(text, text) from public;
revoke all on function public.set_current_user_password_hash(text) from public;
revoke all on function public.complete_current_user_email_registration(text, text, smallint) from public;
revoke all on function public.verify_user_login(text, text) from public;

grant execute on function public.set_current_user_password_hash(text) to authenticated;
grant execute on function public.complete_current_user_email_registration(text, text, smallint) to authenticated;
grant execute on function public.verify_user_login(text, text) to anon, authenticated;
