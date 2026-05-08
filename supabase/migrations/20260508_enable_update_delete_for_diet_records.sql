alter table public.diet_records enable row level security;

drop policy if exists "diet_records_update_own" on public.diet_records;
create policy "diet_records_update_own"
on public.diet_records
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "diet_records_delete_own" on public.diet_records;
create policy "diet_records_delete_own"
on public.diet_records
for delete
to authenticated
using (auth.uid() = user_id);

grant update, delete on public.diet_records to authenticated;
