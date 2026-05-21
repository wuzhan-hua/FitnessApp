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

## Vercel 部署（推荐）

本项目已经补充了 `Vercel` 所需的仓库配置文件：

- `vercel.json`
- `tool/vercel_prepare.sh`
- `tool/vercel_build.sh`

这些文件的作用：

- 在 Vercel 构建机中准备 Flutter Web 构建环境
- 自动执行 `flutter pub get`
- 将 `SUPABASE_URL`、`SUPABASE_ANON_KEY` 注入到 `flutter build web`
- 产出 `build/web`
- 对单页应用路由做 `index.html` 回退，避免刷新子路径时出现 `404`

当前仓库默认要求 Vercel 构建机使用 `Flutter 3.44.0`。如果之前构建缓存里已经存在旧版 Flutter，仓库中的准备脚本会自动清理旧 SDK 并重新安装；修复配置后重新部署一次即可。

### 一、准备工作

1. 确保代码已经推送到 GitHub 仓库
2. 准备好 Supabase 的两个公开配置：
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
3. 购买一个自己的域名（可选，但如果你要给朋友长期访问，建议购买）

### 二、导入到 Vercel

1. 打开 [Vercel](https://vercel.com/)
2. 使用 GitHub 账号登录
3. 点击 `Add New...` -> `Project`
4. 选择仓库 `wuzhan-hua/FitnessApp`
5. 导入项目

### 三、Vercel 项目配置

由于仓库里已经有 `vercel.json`，大部分配置会自动生效。

如果 Vercel 后台仍要求手动确认，请按以下内容填写：

- Framework Preset: `Other`
- Install Command: `bash tool/vercel_prepare.sh`
- Build Command: `bash tool/vercel_build.sh`
- Output Directory: `build/web`

### 四、配置环境变量

在 Vercel 项目后台打开：

`Settings` -> `Environment Variables`

新增以下两个变量：

- `SUPABASE_URL` = 你的 Supabase 项目地址
- `SUPABASE_ANON_KEY` = 你的 Supabase 匿名公钥

注意：

- 这两个值不是运行时动态读取，而是构建 Flutter Web 时通过 `--dart-define` 注入
- 如果漏配，部署会直接失败，并提示缺少环境变量

### 五、首次部署

完成上述配置后点击部署。

部署成功后，Vercel 会先分配一个临时访问地址，例如：

`https://xxx.vercel.app`

你可以先把这个地址发给朋友预览。

### 六、绑定自定义域名

如果你已经购买域名：

1. 打开 Vercel 项目
2. 进入 `Settings` -> `Domains`
3. 输入你的域名，例如：
   - `fitness.yourdomain.com`
   - `www.yourdomain.com`
4. 按照 Vercel 页面提示，在域名服务商后台配置 DNS

常见情况：

- 子域名通常配置 `CNAME`
- 根域名通常按 Vercel 提示配置 `A` 记录或 nameserver

DNS 生效后，Vercel 会自动签发 HTTPS 证书。

### 七、后续更新

后续只要你继续往 GitHub 仓库 push：

- Vercel 会自动重新构建
- 新版本会自动上线
- 不需要重复手动上传静态文件

### 八、上线前检查清单

建议你在正式发给朋友前检查以下内容：

- 首页能正常打开
- 登录流程正常
- 训练记录页面能正常加载
- 刷新页面不会出现 `404`
- 手机浏览器可以正常访问
- 域名地址为 `https`

## GitHub Pages 说明（备选）

GitHub 可以免费提供：

- `你的用户名.github.io`

这只是 GitHub 的二级域名，不是可注册、可独占的独立域名。

如果你想用自己的域名，例如 `yourapp.com`，仍然需要：

1. 自己购买域名
2. 再把域名绑定到 GitHub Pages

对于本项目，不优先推荐 GitHub Pages，原因是 Flutter Web 单页应用在以下方面更容易额外处理：

- `base href`
- 静态资源路径
- 子路径刷新 `404`

如果你只是想尽快稳定给朋友访问，优先使用 `Vercel`。

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

## 食物库导入

如需将 `assets/datasets/china-food-composition` 导入到当前 Supabase 项目，先执行对应 migration，再运行导入脚本：

```bash
SUPABASE_URL=你的_SUPABASE_URL \
SUPABASE_SERVICE_ROLE_KEY=你的_SUPABASE_SERVICE_ROLE_KEY \
dart run tool/import_china_food_composition.dart
```

可选环境变量：

- `CHINA_FOOD_COMPOSITION_DIR`：默认 `assets/datasets/china-food-composition`
- `CHINA_FOOD_IMPORT_BATCH_SIZE`：默认 `100`
