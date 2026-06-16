# 温湿度监控 App — 开发与编译指南

## 开发工作流

1. **本地只写代码，不编译 APK**
   - 本地用 `flutter analyze` 检查语法和类型错误
   - 本地用 `flutter test` 运行单元测试
   - APK 编译统一走 GitHub Actions CI

2. **提交流程**
   - 每次 commit 后 push 到 `master`
   - GitHub Actions 自动触发 Build Android APK workflow
   - CI 流程：`flutter pub get` → `dart run build_runner build` → `flutter analyze` → `flutter build apk --debug`
   - 下载 APK 产物：GitHub → Actions → 对应 run → Artifacts → `debug-apk.zip`

3. **CI 失败时**
   - `gh run list --limit 1` 查看最新 run
   - `gh run view <run-id> --log | tail -80` 查看错误日志
   - 根据错误日志修改代码，commit + push 重试

## 关键构建配置

### AGP / Gradle 版本
- AGP 8.2.0, Gradle 8.2
- Kotlin 1.9.22, Java 17
- Flutter 3.22.0 (stable)

### Android 构建要点 (`android/app/build.gradle`)
- `compileSdk = 35`（`sqlite3_flutter_libs` 要求）
- `ndkVersion = "25.1.8937393"`（同上）
- `coreLibraryDesugaringEnabled true` + `desugar_jdk_libs:2.0.4`（`flutter_local_notifications` 要求）
- `sourceCompatibility = VERSION_17` / `targetCompatibility = VERSION_17`
- `kotlinOptions { jvmTarget = "17" }`

### Gradle 根项目 (`android/build.gradle`)
- `flutter_blue_plus_android` 需要访问 `flutter.compileSdkVersion`，但 Flutter Gradle Plugin 只在 `:app` 模块注入 `flutter` extension
- 需要在 `subprojects` 中 fallback：`project.ext.flutter = rootProject.ext.flutter`

### AndroidManifest (`android/app/src/main/AndroidManifest.xml`)
- `flutter_background_service_android` 的 `BackgroundService` 声明了 `exported=true`，debug manifest 冲突
- 用 `tools:replace="android:exported"` 解决

### 依赖声明 (`pubspec.yaml`)
- `flutter_bloc` 内部依赖 `provider`，但直接导入 `package:provider/provider.dart` 需要在 `pubspec.yaml` 中显式声明 `provider` 依赖
- `RepositoryProvider` 不接受 `Stream` 子类型，用 `Provider<Stream<Reading>>` 替代

## 测试

### 单元测试
```bash
flutter test
```

### 集成测试（需要真机或模拟器）
```bash
flutter run
flutter test integration_test/app_test.dart
```

## 项目结构

```
lib/
├── app.dart                     # 应用入口，Provider 注册
├── core/                        # 主题、扩展工具
├── data/                        # Drift 数据库、BThome 协议解析
├── domain/
│   └── models/                  # Device, Reading 数据模型
├── infrastructure/              # 调试日志、权限服务、通知服务
├── presentation/                # UI 页面（dashboard, devices, settings, debug）
├── repositories/                # SensorRepository（数据库操作入口）
└── services/                    # 蓝牙扫描、后台服务
```
