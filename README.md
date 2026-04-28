# fitness_client

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Web 启动说明

当前网络环境下，Flutter Web 默认从 `https://www.gstatic.com/flutter-canvaskit/...` 加载 CanvasKit 资源时，可能出现连接失败并导致页面白屏。

本项目已在 Web 启动配置中固定使用本地 CanvasKit，不再依赖 `gstatic` 资源。

本地调试 Web 时，直接使用以下命令启动即可：

```bash
flutter run \
  --dart-define=SUPABASE_URL=你的_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=你的_SUPABASE_ANON_KEY \
  -d chrome
```

如果已经配置了正确的 Supabase 参数，使用上述命令启动后，Web 页面应从本地 `canvaskit` 路径加载资源，不再依赖 `gstatic` 的 CanvasKit 资源。

## 动作库导入

如需将 `free-exercise-db` 导入到当前 Supabase 项目，先执行对应 migration，再运行导入脚本：

```bash
SUPABASE_URL=你的_SUPABASE_URL \
SUPABASE_SERVICE_ROLE_KEY=你的_SUPABASE_SERVICE_ROLE_KEY \
FREE_EXERCISE_DB_LOCAL_ROOT=你的_free-exercise-db_本地目录 \
dart run tool/import_free_exercise_db.dart
```

可选环境变量：

- `FREE_EXERCISE_DB_LOCAL_ROOT`：必填，本地 `free-exercise-db` 仓库根目录
- `FREE_EXERCISE_DB_SOURCE_VERSION`：默认 `main`
- `SUPABASE_EXERCISE_BUCKET`：默认 `exercise-reference`
- `FREE_EXERCISE_DB_BATCH_SIZE`：默认 `50`

当前脚本默认要求使用本地 `free-exercise-db` 仓库，不再依赖 `raw.githubusercontent.com` 下载 JSON 和图片。

## 动作库中文同步

如需将第三方中文数据文件按 `id` 回写到 `exercise_catalog_items.name_zh` 与
`exercise_catalog_items.instructions_zh`，执行：

```bash
SUPABASE_URL=你的_SUPABASE_URL \
SUPABASE_SERVICE_ROLE_KEY=你的_SUPABASE_SERVICE_ROLE_KEY \
FREE_EXERCISE_ZH_JSON_PATH=你的_free-exercise-db-zh.json_本地路径 \
dart run tool/update_exercise_name_zh.dart
```

兼容环境变量：

- `FREE_EXERCISE_NAME_ZH_SOURCE`：旧变量名，语义等同于 `FREE_EXERCISE_ZH_JSON_PATH`
