create or replace function public.is_auth_email_registered(target_email text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  matched_user_id uuid;
begin
  select id
  into matched_user_id
  from auth.users
  where lower(email) = lower(target_email)
  limit 1;

  return matched_user_id is not null;
end;
$$;

revoke all on function public.is_auth_email_registered(text) from public;
grant execute on function public.is_auth_email_registered(text) to service_role;
