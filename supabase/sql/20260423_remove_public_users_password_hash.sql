revoke all on function public.hash_user_password(text) from public;
revoke all on function public.verify_user_password(text, text) from public;
revoke all on function public.set_current_user_password_hash(text) from public;
revoke all on function public.complete_current_user_email_registration(text, text, smallint) from public;
revoke all on function public.verify_user_login(text, text) from public;

drop function if exists public.verify_user_login(text, text);
drop function if exists public.complete_current_user_email_registration(text, text, smallint);
drop function if exists public.set_current_user_password_hash(text);
drop function if exists public.verify_user_password(text, text);
drop function if exists public.hash_user_password(text);

alter table public.users
  drop column if exists password_hash;

comment on column public.users.user_type is '0=游客 1=邮箱账号，仅作业务标记，不参与认证';
comment on column public.users.email is 'auth.users.email 的业务镜像字段，不作为认证主数据';

update public.users u
set email = a.email,
    email_verified_at = a.email_confirmed_at,
    phone = a.phone,
    last_sign_in_at = a.last_sign_in_at,
    updated_at = now()
from auth.users a
where u.user_id = a.id;
