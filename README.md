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
