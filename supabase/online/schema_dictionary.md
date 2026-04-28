# Supabase 数据字典

基于 [mySql.sql](/Users/mac/Projects/fitness_Projects/fitness_client/supabase/online/mySql.sql) 整理。本文档只覆盖当前线上导出中的 `public` schema 业务表，不覆盖 `auth.users` 等 Supabase 内建系统表的完整字段字典。

当前线上导出里共有 7 张业务表：

1. `users`
2. `user_profiles`
3. `signup_verification_codes`
4. `workout_sessions`
5. `workout_exercises`
6. `workout_sets`
7. `workout_records`
8. `exercise_catalog_items`

## 总览

| 表名 | 中文含义 | 一句话说明 |
| --- | --- | --- |
| `users` | 业务用户表 | `auth.users` 的业务镜像表，存账号层业务字段，不负责认证本身。 |
| `user_profiles` | 用户个人资料表 | 存用户的基础资料，如姓名、生日、身高、体重、训练背景。 |
| `signup_verification_codes` | 验证码表 | 存注册/游客升级邮箱时用到的验证码及其发送状态。 |
| `workout_sessions` | 训练会话表 | 存一整次训练的主记录，是可编辑中的训练容器。 |
| `workout_exercises` | 会话动作表 | 存某次训练里包含了哪些动作，以及动作顺序和目标组数。 |
| `workout_sets` | 训练组明细表 | 存某个动作下每一组的实际训练数据。 |
| `workout_records` | 训练归档快照表 | 存已归档的历史训练快照，设计上用于追溯，不用于持续编辑。 |
| `exercise_catalog_items` | 动作目录表 | 存全局共享的动作基础信息、肌群分类和参考图片路径，用于动作库选择。 |

## 表级说明

### `users`

- 表名中文含义：业务用户表
- 业务用途：补充 `auth.users` 没有的业务字段，作为 App 内“这个用户”的业务主入口。
- 角色定位：它不是认证主表，认证主数据仍在 `auth.users`。
- 典型场景：
  - 记录用户最近登录时间
  - 标记用户是游客还是邮箱账号
  - 作为 `user_profiles` 的上游主表
- 主键：`id`
- 唯一键：`user_id`
- 外键：`user_id -> auth.users.id`
- 备注：
  - `on delete cascade` 表示认证用户被删时，这里的业务镜像也会一起删。
  - 有 `updated_at` 自动更新时间触发器。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | `uuid` | 这张业务表自己的主键。通常内部唯一标识使用，但业务关联更多是走 `user_id`。 |
| `user_id` | `uuid` | 对应 `auth.users.id`，表示“这是哪个认证用户”。这是最核心的业务用户标识。 |
| `created_at` | `timestamptz` | 业务用户记录创建时间。 |
| `nickname` | `text` | 用户昵称。当前线上库已有该字段。 |
| `avatar_url` | `text` | 用户头像地址。当前线上库已有该字段。 |
| `email` | `text` | 邮箱的业务镜像字段，用于业务展示/查询，不是认证主数据。 |
| `email_verified_at` | `timestamptz` | 邮箱验证完成时间的业务镜像。 |
| `phone` | `text` | 手机号的业务镜像字段。 |
| `last_sign_in_at` | `timestamptz` | 最近一次登录时间的业务镜像。 |
| `updated_at` | `timestamptz` | 最近更新时间，由触发器自动维护。 |
| `is_profile_completed` | `boolean` | 是否已完成个人资料填写。用于流程判断，不代表训练资料一定完整。 |
| `user_type` | `smallint` | 用户类型业务标记。当前约束是 `0=游客`，`1=邮箱账号`。 |

### `user_profiles`

- 表名中文含义：用户个人资料表
- 业务用途：存用户的基础身体信息和训练背景信息。
- 角色定位：这是“个人资料”，不是“认证资料”，也不是“训练记录”。
- 典型场景：
  - 个人信息页展示和保存
  - 后续做训练建议、热量估算、档案展示
- 主键：`user_id`
- 外键：`user_id -> users.user_id`
- 备注：
  - 一名用户最多一条个人资料记录。
  - 有 `updated_at` 自动更新时间触发器。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `user_id` | `uuid` | 对应 `users.user_id`，表示这份资料属于哪个用户。也是主键。 |
| `profile_name` | `text` | 个人资料中的姓名或展示名。 |
| `gender` | `text` | 性别。当前未见枚举约束，业务上应自行控制可选值。 |
| `birth_date` | `date` | 生日。只存日期，不存具体时分秒。 |
| `height_cm` | `numeric` | 身高，单位厘米。 |
| `weight_kg` | `numeric` | 当前身体体重，单位公斤。不是训练时举的重量。 |
| `training_goal` | `text` | 训练目标，如增肌、减脂、维持。 |
| `training_years` | `text` | 训练年限。当前是文本型，不是数值型。 |
| `activity_level` | `text` | 日常活动水平。 |
| `created_at` | `timestamptz` | 个人资料创建时间。 |
| `updated_at` | `timestamptz` | 个人资料最近更新时间。 |

### `signup_verification_codes`

- 表名中文含义：验证码表
- 业务用途：存邮箱验证码及发送/使用状态。
- 角色定位：这是临时流程数据，不是用户正式资料。
- 典型场景：
  - 邮箱注册前发送验证码
  - 游客升级邮箱账号时发送验证码
- 主键：`id`
- 唯一键：`lower(email) + purpose`
- 备注：
  - 同一个邮箱在同一种用途下只保留一条有效记录。
  - `purpose` 用于区分注册验证码和游客升级验证码。
  - 有 `updated_at` 自动更新时间触发器。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | `uuid` | 验证码记录主键。 |
| `email` | `text` | 接收验证码的邮箱。 |
| `code_hash` | `text` | 验证码的哈希值，不直接存明文验证码。 |
| `expires_at` | `timestamptz` | 验证码过期时间。 |
| `consumed_at` | `timestamptz` | 验证码被使用的时间，未使用时为空。 |
| `created_at` | `timestamptz` | 这条验证码记录首次创建时间。 |
| `last_sent_at` | `timestamptz` | 最近一次发送验证码时间。 |
| `updated_at` | `timestamptz` | 最近更新时间。 |
| `send_count` | `integer` | 该邮箱在该用途下已发送次数。 |
| `request_fingerprint` | `text` | 请求指纹，用于风控或限制频率。 |
| `purpose` | `text` | 验证码用途。当前约束值为 `signup` 或 `guest_upgrade`。 |

### `workout_sessions`

- 表名中文含义：训练会话表
- 业务用途：表示“一整次训练”这件事的主记录。
- 角色定位：它是训练编辑过程的根节点，下面再挂动作和组。
- 典型场景：
  - 创建今天的训练草稿
  - 继续编辑训练
  - 把训练标记为完成
- 主键：`id`
- 唯一键：`id + user_id`
- 外键：`user_id -> auth.users.id`
- 备注：
  - `status` 受约束，只能是 `draft`、`in_progress`、`completed`。
  - 线上有阻止已完成会话更新/删除的触发器，说明已完成训练不应随意改写。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | `uuid` | 一次训练会话的主键。 |
| `user_id` | `uuid` | 这次训练属于哪个用户。 |
| `created_at` | `timestamptz` | 训练会话创建时间。 |
| `date` | `timestamptz` | 训练日期/时间。当前代码主要把它当作训练发生日期使用。 |
| `title` | `text` | 本次训练标题，如“推训练日”“新训练日”。 |
| `status` | `text` | 训练生命周期状态，不是通用状态。`draft`=草稿，`in_progress`=进行中，`completed`=已完成。 |
| `duration_minutes` | `integer` | 本次训练总时长，单位分钟。 |
| `notes` | `text` | 本次训练的备注。 |

### `workout_exercises`

- 表名中文含义：会话动作表
- 业务用途：表示某次训练包含哪些动作。
- 角色定位：它连接“训练会话”和“每组数据”，是一条动作行。
- 典型场景：
  - 某次胸推日里有“杠铃卧推”“上斜哑铃卧推”
  - 控制动作顺序和目标组数
- 主键：`id`
- 唯一键：`id + user_id`
- 外键：
  - `(session_id, user_id) -> workout_sessions (id, user_id)`
  - `user_id -> auth.users.id`
- 备注：
  - 删除会话时，动作记录会级联删除。
  - `exercise_id` 和 `id` 不同，前者更像动作目录标识，后者是这次会话里的动作行标识。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | `uuid` | 这条动作行自身的主键。 |
| `user_id` | `uuid` | 这条动作行属于哪个用户。 |
| `created_at` | `timestamptz` | 动作行创建时间。 |
| `session_id` | `uuid` | 这条动作属于哪一次训练会话。 |
| `exercise_id` | `text` | 动作目录 ID，例如某个预设动作编码。不是这条行记录的主键。 |
| `exercise_name` | `text` | 动作名称，例如“杠铃卧推”。 |
| `target_sets` | `integer` | 计划做几组。是目标值，不一定等于最终实际组数。 |
| `sort_order` | `integer` | 该动作在整次训练中的顺序，从前到后排序用。 |

### `workout_sets`

- 表名中文含义：训练组明细表
- 业务用途：表示某个动作下每一组的实际训练数据。
- 角色定位：这是训练数据最细的一层。
- 典型场景：
  - 第 1 组卧推 60kg x 8 次
  - 第 2 组卧推 65kg x 8 次
  - 有氧组记录时长和距离
- 主键：`id`
- 唯一键：`exercise_row_id + set_index`
- 外键：
  - `(session_id, user_id) -> workout_sessions (id, user_id)`
  - `(exercise_row_id, user_id) -> workout_exercises (id, user_id)`
  - `user_id -> auth.users.id`
- 备注：
  - `set_index` 是动作内第几组，不是整场训练第几条记录。
  - `set_type` 当前只有 `strength` 和 `cardio`。
  - 这张表的 `weight` 是训练负重，不是用户体重。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | `uuid` | 单组记录主键。 |
| `user_id` | `uuid` | 这组数据属于哪个用户。 |
| `created_at` | `timestamptz` | 该组记录创建时间。 |
| `session_id` | `uuid` | 这组数据属于哪一次训练会话。 |
| `exercise_row_id` | `uuid` | 这组数据属于哪一条动作行。不是动作目录 ID。 |
| `set_index` | `integer` | 该动作内的第几组，必须大于 0。 |
| `weight` | `numeric(10,2)` | 训练负重，单位公斤。力量组常用；有氧组通常为 0。 |
| `reps` | `integer` | 次数。力量组常用；有氧组可为 0。 |
| `rest_seconds` | `integer` | 该组后的休息秒数。 |
| `is_completed` | `boolean` | 该组是否已完成。 |
| `set_type` | `text` | 组类型。`strength`=力量组，`cardio`=有氧组。 |
| `duration_minutes` | `integer` | 有氧组时长，单位分钟。力量组通常为空。 |
| `distance_km` | `numeric(10,3)` | 有氧组距离，单位公里。力量组通常为空。 |

### `workout_records`

- 表名中文含义：训练归档快照表
- 业务用途：存一条已经归档的历史训练快照。
- 角色定位：偏历史追溯，不是当前训练编辑主表。
- 典型场景：
  - 训练完成后留存历史快照
  - 后续统计、回看、审计
- 主键：`id`
- 外键：`user_id -> auth.users.id`
- 备注：
  - 线上有阻止 `update/delete` 的触发器，说明设计上不可改不可删。
  - 它和 `workout_sessions` 不同：`workout_sessions` 是可编辑中的结构化训练；`workout_records` 是归档后的历史快照。

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | `uuid` | 归档记录主键。 |
| `user_id` | `uuid` | 这条归档记录属于哪个用户。 |
| `created_at` | `timestamptz` | 归档记录创建时间。 |
| `session_date` | `date` | 这次训练对应的训练日期。 |
| `title` | `text` | 训练标题快照。 |
| `status` | `text` | 归档时的状态快照。默认值是 `draft`，但业务上通常用于保存完成后的历史状态。 |
| `duration_minutes` | `integer` | 训练时长快照。 |
| `exercises` | `jsonb` | 当次训练动作和组数据的 JSON 快照。 |
| `notes` | `text` | 训练备注快照。 |

### `exercise_catalog_items`

- 表名中文含义：动作目录表
- 一句话用途：存全局动作模板、肌群/器械分类、动作说明和参考图片路径，供动作库筛选与选择使用。
- 主键：`id`

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | `text` | 动作目录唯一标识，直接对应导入源里的动作 ID。 |
| `name_en` | `text` | 动作英文名。 |
| `name_zh` | `text` | 动作中文名，可为空。 |
| `equipment_en` | `text` | 器械英文名，可为空。 |
| `equipment_zh` | `text` | 器械中文名，可为空。 |
| `category_en` | `text` | 动作分类英文名，如 `strength`、`stretching`。 |
| `category_zh` | `text` | 动作分类中文名。 |
| `primary_muscles_en` | `text[]` | 主要目标肌群英文列表。 |
| `primary_muscles_zh` | `text[]` | 主要目标肌群中文列表。 |
| `secondary_muscles_en` | `text[]` | 次要目标肌群英文列表。 |
| `secondary_muscles_zh` | `text[]` | 次要目标肌群中文列表。 |
| `instructions_en` | `text[]` | 动作说明英文步骤列表。 |
| `instructions_zh` | `text[]` | 动作说明中文步骤列表，当前可为空。 |
| `image_paths` | `text[]` | 动作参考图在存储桶中的对象路径列表。 |
| `cover_image_path` | `text` | 列表封面图在存储桶中的对象路径。 |
| `source` | `text` | 数据来源标记，当前默认 `free-exercise-db`。 |
| `source_version` | `text` | 导入时使用的数据源版本标记，如 `main`。 |
| `is_active` | `boolean` | 当前动作是否启用，用于动作库展示控制。 |
| `created_at` | `timestamptz` | 目录记录创建时间。 |
| `updated_at` | `timestamptz` | 目录记录最近更新时间。 |

## 关系与易混点

### `users` vs `user_profiles`

- `users` 是账号业务镜像表，解决“这个认证用户在业务系统里是谁”。
- `user_profiles` 是个人资料表，解决“这个用户的基础资料是什么”。
- 简单理解：
  - `users` 更偏账号
  - `user_profiles` 更偏档案

### `user_profiles.weight_kg` vs `workout_sets.weight`

- `user_profiles.weight_kg`：用户当前身体体重。
- `workout_sets.weight`：某一组训练时使用的负重。
- 两者单位都可能是 kg，但业务含义完全不同，不能互相替代。

### `workout_sessions` vs `workout_records`

- `workout_sessions`：训练过程中的主记录，可创建、编辑、补录，并挂动作和组。
- `workout_records`：归档后的历史快照，线上触发器已经表明它不应该再被修改或删除。
- 简单理解：
  - `workout_sessions` 是“活数据”
  - `workout_records` 是“历史快照”

### `workout_exercises.exercise_id` vs `workout_exercises.id`

- `exercise_id`：动作目录 ID，代表“这是什么动作”。
- `id`：这次训练里这条动作行自己的 ID，代表“这次训练中的这条记录”。

### `workout_sets.exercise_row_id` vs `workout_exercises.exercise_id`

- `workout_sets.exercise_row_id` 指向的是 `workout_exercises.id`。
- 它表示“这一组挂在本次训练的哪一条动作行下面”。
- 它不是动作目录 ID，不能直接拿去当动作模板标识。

### `set_index`

- `set_index` 是动作内部组序号。
- 它只在同一个 `exercise_row_id` 下有意义。
- 例如卧推第 1 组和飞鸟第 1 组都可以同时存在，不冲突。

### `purpose`

- `signup_verification_codes.purpose` 用来区分验证码业务用途。
- 当前线上约束只有两种：
  - `signup`
  - `guest_upgrade`

## 维护建议

- 以后若线上库结构变化，先更新 [mySql.sql](/Users/mac/Projects/fitness_Projects/fitness_client/supabase/online/mySql.sql)，再同步更新本文档。
- 如果后续增加新的资料字段、训练表或统计表，建议继续沿用这份文档的写法：
  - 先写“这张表是干什么的”
  - 再写“每个字段的业务语义”
  - 最后写“容易和谁混淆”
