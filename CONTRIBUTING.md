# 贡献指南

感谢你关注 `FitnessApp`。

本项目当前处于持续演进阶段，欢迎通过 Issue、讨论和 Pull Request 一起完善训练记录与饮食管理体验。

## 开始之前

提交贡献前，建议先阅读以下内容：

- [README](/Users/mac/Projects/fitness_Projects/fitness_client/README.md)
- [行为准则](/Users/mac/Projects/fitness_Projects/fitness_client/CODE_OF_CONDUCT.md)
- [安全策略](/Users/mac/Projects/fitness_Projects/fitness_client/SECURITY.md)

## 你可以如何参与

- 报告 Bug
- 提交功能建议
- 改进文档
- 修复问题或补充测试
- 优化训练、饮食、管理后台等现有体验

## 提交 Issue

如果你发现问题或有产品建议，请优先通过 GitHub Issue 提交：

- Bug 使用 `Bug Report` 模板
- 功能建议使用 `Feature Request` 模板

提交前请尽量确认：

- 问题可以稳定复现
- 问题描述清晰
- 已附带必要截图、日志或复现步骤

## 提交 Pull Request

### 分支建议

建议使用清晰的分支命名，例如：

- `feat/workout-history-filter`
- `fix/web-auth-redirect`
- `docs/readme-roadmap`

### 开发约束

请遵循仓库已有约束：

- 页面层不要直接访问 Supabase
- 数据请求统一通过 `services` 或 `repositories`
- 状态逻辑放在 `application` 层
- 模型解析放在实体或模型层，不放在 UI 中
- 遵循最小改动原则，不做与目标无关的重构

### 提交前自检

提交 PR 前请尽量确认：

- 代码能正常运行
- 改动范围与目标一致，没有夹带无关修改
- 错误处理清晰，没有静默失败
- 文档在需要时已同步更新

### PR 内容建议

一个高质量 PR 通常应包含：

- 变更背景
- 主要修改点
- 验证方式
- 风险说明
- UI 改动截图或录屏

## 开发环境

本项目当前主要技术栈：

- Flutter
- Riverpod
- Supabase

本地运行常用方式：

```bash
flutter run \
  --dart-define=SUPABASE_URL=你的_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=你的_SUPABASE_ANON_KEY \
  -d chrome
```

## 沟通建议

如果你准备实现较大功能，建议先开 Issue 描述目标、影响范围和方案方向，再开始编码，这样更容易获得及时反馈，也能避免重复工作。
