# iOS App Store 上架执行清单

本文档基于当前仓库状态整理，适用于 `2026-05-22` 这一版代码。

## 1. Supabase 部署步骤

当前仓库已新增以下上架相关后端能力：

- migration: `supabase/migrations/20260522_add_delete_account_capability.sql`
- Edge Function: `supabase/functions/delete-account/index.ts`

当前 Supabase CLI 版本：

```bash
supabase --version
# 2.90.0
```

当前仓库关联的 Supabase 项目 ref：

```text
iywzidbfmxukdawkrfto
```

### 1.1 登录并确认链接项目

```bash
supabase login
supabase link --project-ref iywzidbfmxukdawkrfto
```

如果本地已经 link 过，可先执行：

```bash
supabase status
```

### 1.2 部署数据库 migration

```bash
supabase db push
```

本次 migration 会做三件事：

- 保留 `records` / `completed workout_sessions` 的普通删除保护
- 为“删除账号”流程增加受控放行
- 新增 `public.delete_account_data(uuid)` 供服务端调用

### 1.3 部署 Edge Function

```bash
supabase functions deploy delete-account
```

### 1.4 确认函数所需环境变量

`delete-account` 依赖服务端已有的 Supabase 基础环境变量：

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

如果项目之前已经部署过注册相关函数，通常这两个 secret 已存在。仍建议复核一次：

```bash
supabase secrets list
```

如需补充：

```bash
supabase secrets set \
  SUPABASE_URL=你的_SUPABASE_URL \
  SUPABASE_SERVICE_ROLE_KEY=你的_SUPABASE_SERVICE_ROLE_KEY
```

### 1.5 部署后建议验证

建议在测试环境或生产测试账号上实际走一遍：

1. 邮箱账号登录
2. 创建几条训练记录、饮食记录
3. 上传头像
4. 进入“我的” -> “删除账号”
5. 确认删除后：
   - 当前会话失效
   - 原账号重新登录失败
   - 用户数据被清理

## 2. App 内配置项

当前代码中，隐私政策与用户协议地址配置位在：

- [lib/constants/legal_constants.dart](/Users/mac/Projects/fitness_Projects/fitness_client/lib/constants/legal_constants.dart)

上架前请替换为正式线上 URL：

```dart
static const String privacyPolicyUrl = 'https://你的域名/privacy';
static const String termsOfServiceUrl = 'https://你的域名/terms';
```

如果不替换，App 内入口会提示“请先配置地址后再使用”，不会直接崩溃，但不满足正式上架预期。

## 3. App Review Notes 模板

以下内容可直接作为 App Store Connect `App Review Information` / `Review Notes` 的基础模板，再替换其中占位信息。

```text
App Name: 即训

Test account:
Email: [填入审核测试邮箱]
Password: [填入审核测试密码]

Login notes:
1. Open the app and sign in with the test account above.
2. The app supports workout logging, diet logging, profile editing, and avatar upload.
3. Photo Library permission is only used for selecting a profile avatar image.

Account deletion path:
Profile -> 删除账号

Additional notes:
- This app does not use paid content, subscriptions, or Apple Sign In.
- Anonymous guest mode may exist for limited onboarding/testing flows, but the review account above can access the full core experience.
```

建议你在实际提交时再补两项：

- 测试账号中预置 2-3 条训练记录、1-2 条饮食记录、1 张头像
- 如果后台有频率限制或验证码限制，明确说明审核账号无需验证码即可登录

## 4. App Privacy 问卷填写建议

以下是基于当前仓库代码的建议答案草稿，不替代你在 App Store Connect 中的最终法律确认。

### 4.1 当前代码可识别的数据类型

当前项目明确涉及：

- 邮箱地址
- 用户上传头像
- 用户训练记录
- 用户饮食记录
- 用户基础档案信息
  - 姓名/昵称
  - 性别
  - 生日
  - 身高
  - 体重
  - 训练目标
  - 训练年限
  - 活动水平

### 4.2 建议申报为“会收集”的数据

建议在 App Privacy 中至少申报：

- Contact Info
  - Email Address
- User Content
  - Photos or Videos
  - Other User Content
- Health & Fitness
  - Fitness

### 4.3 这些数据的用途建议

建议用途勾选：

- App Functionality

如果你没有做广告、画像、第三方跟踪，不要勾选：

- Third-Party Advertising
- Developer’s Advertising or Marketing
- Analytics（除非你后续实际接入统计 SDK）
- Product Personalization（除非你后续真的做推荐画像）

### 4.4 建议回答为“不跟踪”

当前代码未看到广告跟踪、跨 App 跟踪或 ATT 相关实现，建议：

- Data Used to Track You: `No`
- Tracking: `No`

## 5. App Store Connect 元数据检查

提交前至少核对以下项目：

1. App 名称：`即训`
2. 副标题、描述、关键词
3. 版本号与构建号是否和本次上传包一致
4. 应用图标、启动页、iPhone 截图
5. 年龄分级
6. 隐私政策 URL
7. 审核联系人信息
8. Review Notes

## 6. 本地验证记录

当前这版代码已完成以下验证：

```bash
flutter pub get
flutter analyze
plutil -lint ios/Runner/Info.plist ios/Runner/PrivacyInfo.xcprivacy
flutter build ios --simulator --no-codesign
```

其中 iOS 模拟器构建已成功产出：

```text
build/ios/iphonesimulator/Runner.app
```

## 7. 上架前最后检查

在真正提交审核前，建议再人工确认一次：

1. “隐私政策 / 用户协议”入口能正常打开正式 URL
2. “删除账号”能真实删除账号与关联数据
3. 游客登录、邮箱登录、游客升级邮箱账号不回归
4. 相册权限弹窗文案符合实际用途
5. 测试账号稳定可登录，且数据已预置
