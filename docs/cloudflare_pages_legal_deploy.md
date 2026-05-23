# Cloudflare Pages 法律页面部署说明

本文档用于将“即训”项目中的法律页面发布到 `Cloudflare Pages`，并通过以下正式地址对外提供访问：

- `https://wzhua.indevs.in/privacy`
- `https://wzhua.indevs.in/terms`

## 1. 发布目标

当前项目已内置法律静态页：

- `web-static/privacy/index.html`
- `web-static/terms/index.html`

当前 `Cloudflare Pages` 发布不再依赖 Flutter Web 构建，而是直接复制法律静态页到专用产物目录：

- `dist/privacy/index.html`
- `dist/terms/index.html`

因此，只要 `Cloudflare Pages` 发布目录指向 `dist`，即可直接得到 `/privacy` 与 `/terms` 两个页面路径。

## 2. Cloudflare Pages 项目配置

在 `Cloudflare Dashboard -> Workers & Pages -> Create application -> Pages -> Connect to Git` 中完成项目创建，并使用以下配置：

- Framework preset：`None`
- Build command：`mkdir -p dist/privacy dist/terms && cp web-static/privacy/index.html dist/privacy/index.html && cp web-static/terms/index.html dist/terms/index.html`
- Build output directory：`dist`
- Root directory：项目根目录
- Deployment command：留空或删除，不使用 `wrangler pages deploy`

## 3. Pages 环境变量

本轮方案不需要额外配置 Cloudflare API 凭据。

说明：

- 本轮只发布法律静态页，不再构建 Flutter Web。
- 因此不需要 `SUPABASE_URL` 与 `SUPABASE_ANON_KEY`。
- 也不需要 `CLOUDFLARE_API_TOKEN` 与 `CLOUDFLARE_ACCOUNT_ID`。
- `Cloudflare Pages` 直接读取 `dist` 目录作为发布产物。

## 4. 自定义域名绑定

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

## 5. 发布后项目内配置

当前 App 内法律链接常量应保持为正式地址：

```dart
static const String privacyPolicyUrl = 'https://wzhua.indevs.in/privacy';
static const String termsOfServiceUrl = 'https://wzhua.indevs.in/terms';
```

对应文件：

- `lib/constants/legal_constants.dart`

## 6. 发布前本地校验

建议在本地先执行以下检查：

```bash
mkdir -p dist/privacy dist/terms && cp web-static/privacy/index.html dist/privacy/index.html && cp web-static/terms/index.html dist/terms/index.html
```

然后确认产物存在：

- `dist/privacy/index.html`
- `dist/terms/index.html`

## 7. 发布后验收

发布完成后至少验证以下项目：

- `https://wzhua.indevs.in/privacy` 可公开访问
- `https://wzhua.indevs.in/terms` 可公开访问
- 页面为有效 HTTPS，无证书报错
- App 内“隐私政策”入口能打开 `/privacy`
- App 内“用户协议”入口能打开 `/terms`
- App Store Connect 中填写的隐私政策 URL 可直接访问

## 8. 当前仍待补字段

本轮已确定正式域名，但法律文档中以下字段仍需你后续补齐：

- 更新日期
- 生效日期

这些字段当前不会阻塞 Pages 部署，但在正式提审前建议补完整。
