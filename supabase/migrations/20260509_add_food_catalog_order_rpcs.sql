create or replace function public.save_food_catalog_item_orders(
  p_category_id uuid,
  order_rows jsonb
)
returns table(id uuid, sort_order integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  expected_count integer;
  updated_count integer;
begin
  if not exists (
    select 1
    from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  ) then
    raise exception '只有管理员可以保存食物排序。';
  end if;

  select count(*) into expected_count
  from jsonb_array_elements(order_rows);

  update public.food_catalog_items as item
  set sort_order = payload.ordinality - 1
  from (
    select
      (row->>'id')::uuid as id,
      row_number() over (order by ordinality)::integer as ordinality
    from jsonb_array_elements(order_rows) with ordinality as items(row, ordinality)
  ) as payload
  where item.id = payload.id
    and item.category_id = p_category_id;

  get diagnostics updated_count = row_count;

  if updated_count <> expected_count then
    raise exception '食物排序保存未生效：期望更新 % 条，实际更新 % 条。', expected_count, updated_count;
  end if;

  return query
  select item.id, item.sort_order
  from public.food_catalog_items as item
  where item.category_id = p_category_id
  order by item.sort_order, item.food_name;
end;
$$;

create or replace function public.save_food_category_orders(order_rows jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1
    from public.users
    where users.user_id = auth.uid()
      and users.is_admin = true
  ) then
    raise exception '只有管理员可以保存食物分类排序。';
  end if;

  update public.food_categories as category
  set sort_order = payload.sort_order
  from (
    select
      (row->>'id')::uuid as id,
      (row->>'sort_order')::integer as sort_order
    from jsonb_array_elements(order_rows) as row
  ) as payload
  where category.id = payload.id;
end;
$$;

grant execute on function public.save_food_catalog_item_orders(uuid, jsonb)
  to authenticated;

grant execute on function public.save_food_category_orders(jsonb)
  to authenticated;

notify pgrst, 'reload schema';
