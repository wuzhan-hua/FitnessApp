alter table public.signup_verification_codes
  add column if not exists purpose text not null default 'signup';

update public.signup_verification_codes
set purpose = 'signup'
where purpose is null or btrim(purpose) = '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'signup_verification_codes_purpose_check'
      and conrelid = 'public.signup_verification_codes'::regclass
  ) then
    alter table public.signup_verification_codes
      add constraint signup_verification_codes_purpose_check
      check (purpose in ('signup', 'guest_upgrade'));
  end if;
end
$$;

drop index if exists signup_verification_codes_email_unique_idx;

create unique index if not exists signup_verification_codes_email_purpose_unique_idx
  on public.signup_verification_codes (lower(email), purpose);
