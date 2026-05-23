# Cloudflare Pages 法律页面部署说明

本文档用于将“即训”项目中的法律页面发布到 `Cloudflare Pages`，并通过以下正式地址对外提供访问：

- `https://wzhua.indevs.in/privacy`
- `https://wzhua.indevs.in/terms`

## 1. 发布目标

当前项目已内置法律静态页：

- `web-static/privacy/index.html`
- `web-static/terms/index.html`

当前方案不再依赖 Flutter Web 构建，也不使用 `wrangler pages deploy`，而是本地生成专用产物目录后，通过 `Cloudflare Pages` 的 `Direct Upload` 直接上传：

- `dist/privacy/index.html`
- `dist/terms/index.html`

因此，只要上传 `dist` 目录，即可直接得到 `/privacy` 与 `/terms` 两个页面路径。

## 2. 本地生成上传目录

在项目根目录执行：

```bash
bash tool/cloudflare_pages_legal_build.sh
```

脚本会生成以下产物：

- `dist/privacy/index.html`
- `dist/terms/index.html`

如果你不想使用脚本，也可以直接执行等价命令：

```bash
mkdir -p dist/privacy dist/terms && cp web-static/privacy/index.html dist/privacy/index.html && cp web-static/terms/index.html dist/terms/index.html
```

## 3. Cloudflare Pages 项目配置

在 `Cloudflare Dashboard -> Workers & Pages -> Create application -> Pages` 中，选择：

- `Direct Upload`

创建项目时建议使用：

- Project name：`jixun-legal`
- Upload folder：本地生成好的 `dist`

说明：

- 不要选择 `Connect to Git`
- 不要使用 `Build command`
- 不要使用 `Deployment command`
- 不要填写“非生产分支部署命令”

如果当前页面出现“构建命令 / 部署命令 / 非生产分支部署命令”，说明你进入的是 Git 构建流，不是本方案需要的入口。请返回并重新选择 `Direct Upload`。

## 4. Pages 环境变量

本轮方案不需要额外配置 Cloudflare API 凭据。

说明：

- 本轮只发布法律静态页，不构建 Flutter Web。
- 因此不需要 `SUPABASE_URL` 与 `SUPABASE_ANON_KEY`。
- 也不需要 `CLOUDFLARE_API_TOKEN` 与 `CLOUDFLARE_ACCOUNT_ID`。
- `Cloudflare Pages` 直接托管你上传的 `dist` 目录。

## 5. 自定义域名绑定

在 `Custom domains` 中添加：

- `wzhua.indevs.in`

推荐做法：

- 优先使用 `Cloudflare Pages` 提供的自动 DNS 配置能力。
- 不手动猜测或预填记录值，避免和 Pages 生成的目标记录冲突。

目标结果：

- `https://wzhua.indevs.in/privacy`
- `https://wzhua.indevs.in/terms`

当前方案保持路径式 URL，不新增以下子域名：

- `privacy.wzhua.indevs.in`
- `terms.wzhua.indevs.in`

## 6. 发布后项目内配置

当前 App 内法律链接常量应保持为正式地址：

```dart
static const String privacyPolicyUrl = 'https://wzhua.indevs.in/privacy';
static const String termsOfServiceUrl = 'https://wzhua.indevs.in/terms';
```

对应文件：

- `lib/constants/legal_constants.dart`

## 7. 发布前本地校验

建议在本地先执行以下检查：

```bash
bash tool/cloudflare_pages_legal_build.sh
```

然后确认产物存在：

- `dist/privacy/index.html`
- `dist/terms/index.html`

上传后，Cloudflare 会先给你一个默认域名，通常可先用类似以下地址预验收：

- `https://jixun-legal.pages.dev/privacy`
- `https://jixun-legal.pages.dev/terms`

## 8. 发布后验收

发布完成后至少验证以下项目：

- `https://wzhua.indevs.in/privacy` 可公开访问
- `https://wzhua.indevs.in/terms` 可公开访问
- 页面为有效 HTTPS，无证书报错
- App 内“隐私政策”入口能打开 `/privacy`
- App 内“用户协议”入口能打开 `/terms`
- App Store Connect 中填写的隐私政策 URL 可直接访问

## 9. 当前仍待补字段

本轮已确定正式域名，但法律文档中以下字段仍需你后续补齐：

- 更新日期
- 生效日期

这些字段当前不会阻塞 Pages 部署，但在正式提审前建议补完整。
