create temporary table tmp_back_group_orders on commit drop as
with back_group_candidates as (
  select
    user_id,
    exercise_id,
    case
      when muscle_group = '背部' then 0
      when muscle_group = '中背' then 1
      when muscle_group = '下背' then 2
      else 3
    end as group_priority,
    sort_order,
    created_at,
    id
  from public.exercise_catalog_item_orders
  where muscle_group in ('背部', '中背', '下背')
),
deduplicated_back_group as (
  select
    user_id,
    exercise_id,
    group_priority,
    sort_order,
    created_at,
    id,
    row_number() over (
      partition by exercise_id
      order by group_priority, sort_order, created_at, id
    ) as exercise_rank
  from back_group_candidates
)
select
  user_id,
  exercise_id,
  '背部'::text as muscle_group,
  row_number() over (
    order by group_priority, sort_order, created_at, id
  ) - 1 as sort_order
from deduplicated_back_group
where exercise_rank = 1;

delete from public.exercise_catalog_item_orders
where muscle_group in ('背部', '中背', '下背');

insert into public.exercise_catalog_item_orders (
  user_id,
  exercise_id,
  muscle_group,
  sort_order
)
select
  user_id,
  exercise_id,
  muscle_group,
  sort_order
from tmp_back_group_orders
on conflict (exercise_id, muscle_group) do update
set
  user_id = excluded.user_id,
  sort_order = excluded.sort_order;
