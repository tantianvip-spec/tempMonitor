# temp_monitor 开发流程设计

- **日期**：2026-06-16
- **状态**：待实施
- **适用范围**：temp_monitor Flutter 项目（Android 为主，iOS 预留）
- **作者**：AI 编码代理 + 项目负责人

## 1. 目标与范围

本文档定义 `temp_monitor` 项目从需求到发布的完整开发流程，包括：

- 分支与版本策略
- 日常开发工作流
- 测试策略
- CI/CD 流水线
- 发版流程
- 热修复与回滚
- AI 代理可执行的工具与检查清单

**关键约束**：

- 本地开发机器配置有限，不执行编译、构建、单元测试；所有重任务由 GitHub Actions 完成。
- 项目当前分支结构为 `master` + `implement`，CI 已基于该结构运行。
- 已有 `.github/workflows/build_android.yml` 构建 Android APK。

## 2. 分支与版本策略

### 2.1 分支模型：GitHub Flow（简化版）

| 分支 | 用途 | 生命周期 |
|---|---|---|
| `master` | 唯一长期分支，始终可发布 | 永久 |
| `implement` | 预发布集成分支 | 永久 |
| `feat/<描述>` | 新功能开发 | 短期，合并后删除 |
| `fix/<描述>` | 普通 bug 修复 | 短期，合并后删除 |
| `hotfix/<版本>-<描述>` | 线上紧急修复 | 短期，合并后删除 |

**分支流向**：

```
feat/*, fix/*  ──►  implement  ──►  master  ──►  GitHub Release
                           ▲
                           └── hotfix/* (反向同步)
```

### 2.2 版本号规则

版本源始终为 `pubspec.yaml`：

```yaml
version: major.minor.patch+build
```

- `major`：不兼容变更（数据库 schema 不兼容、权限模型变更、Android target 大幅升级）
- `minor`：新功能（新增页面、新增设备协议支持、新图表类型）
- `patch`：bug 修复、性能优化、UI 微调
- `+build`：CI 构建号
  - 本地开发保持 `+1`
  - CI 自动使用 `GITHUB_RUN_NUMBER` 替换

### 2.3 Tag 规则

- 正式发布：`v1.2.3`
- 热修复：`v1.2.4`
- 预发布/内测：`v1.3.0-beta.1`

## 3. 开发工作流

### 3.1 任务分解与设计

1. 新功能或复杂修复先写入设计文档：
   `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`
2. 复杂任务再拆分为实施计划：
   `docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md`
3. UI 变更参考：
   `docs/superpowers/design/2026-06-12-ui-design-spec.md`

### 3.2 编码

1. 从 `implement` 切出功能分支：
   ```bash
   git checkout -b feat/dashboard-chart-improvement implement
   ```
2. 本地只做代码编辑和 Git 操作，不执行编译/测试/构建。
3. 由于本地不跑 `build_runner`，**所有 `.g.dart` 生成文件必须提交到仓库**。
4. 提交信息格式：
   ```
   <type>(<scope>): <subject>

   <body>

   Fixes #<issue>
   ```
   - `type`: `feat`, `fix`, `refactor`, `test`, `docs`, `ci`, `chore`
   - `scope`: `ble`, `db`, `ui`, `notif`, `ci`, `parser` 等

### 3.3 代码审查

- 所有合并必须通过 Pull Request，禁止直接 push 到 `implement`/`master`。
- PR 必须填写描述模板：
  - 变更摘要
  - 测试方式
  - 影响范围
  - 是否更新文档
- `implement` 合并需要 CI 通过；`master` 合并需要 CI 通过 + 版本号已更新。

### 3.4 合并

| 源分支 | 目标分支 | 条件 |
|---|---|---|
| `feat/*`, `fix/*` | `implement` | CI `build` 通过 |
| `implement` | `master` | CI 全绿 + 版本号更新 + PR review |
| `hotfix/*` | `master` | CI 全绿 + 版本号更新 + 紧急 review |

## 4. 测试策略

### 4.1 单元测试（CI 执行）

- 命令：
  ```bash
  flutter test --dart-define=APP_VERSION=<version>
  ```
- 必须覆盖：
  - `BThomeParser` / `CustomFirmwareParser`
  - `ThresholdEngine`
  - `SensorRepository`（drift）
  - `DebugLogger`
  - 新增 Cubit / BLoC 状态机

### 4.2 静态分析（CI 执行）

```bash
flutter analyze --no-fatal-warnings
```

### 4.3 生成文件一致性检查（CI 执行）

```bash
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
```

如果 `.g.dart` 与源文件不一致，CI 失败。

### 4.4 集成测试（真机/模拟器）

- 文件：`integration_test/app_test.dart`
- 在以下场景执行：
  - 涉及 BLE 扫描、后台服务、通知权限的变更
  - 发布前最后验证
- 当前不纳入普通 CI（需设备），发布前必须人工或通过 Firebase Test Lab 跑。

### 4.5 发布前回归清单

- [ ] 应用冷启动正常
- [ ] BLE 扫描能发现设备
- [ ] 温湿度数据写入数据库
- [ ] 阈值越界触发通知
- [ ] 后台服务保活 30 分钟以上
- [ ] 黑暗/明亮主题切换正常
- [ ] 数据库保留策略生效

## 5. CI/CD 流水线

### 5.1 现有工作流改造点

在 `.github/workflows/build_android.yml` 基础上扩展：

1. `build` job 增加 `git diff --exit-code` 检查生成文件一致性。
2. `build` job 增加 PR 触发到 `implement` 分支。
3. 新增 `pr-checklist` job（可选），校验 PR 描述和版本号。
4. `release-build` job 增加集成测试占位步骤（`continue-on-error: true`）。

### 5.2 `build` Job 流程

```yaml
触发:
  push: [feat/*, fix/*, implement]
  pull_request: [implement, master]

步骤:
  1. checkout
  2. setup JDK 17
  3. setup Flutter 3.22.0
  4. flutter pub get
  5. dart run build_runner build --delete-conflicting-outputs
  6. git diff --exit-code        # 校验 .g.dart 一致性
  7. flutter analyze --no-fatal-warnings
  8. flutter test --dart-define=APP_VERSION=<version>
  9. flutter build apk --debug --dart-define=APP_VERSION=<version>
 10. upload debug APK artifact
```

### 5.3 `release-build` Job 流程

```yaml
触发:
  push: [master]

步骤:
  1. checkout
  2. extract version from pubspec.yaml
  3. setup JDK 17 + Flutter 3.22.0
  4. flutter pub get
  5. dart run build_runner build --delete-conflicting-outputs
  6. git diff --exit-code
  7. flutter analyze --no-fatal-warnings
  8. flutter test --dart-define=APP_VERSION=<version>
  9. decode keystore + create key.properties
 10. flutter build apk --release --dart-define=APP_VERSION=<version>
 11. rename APK to temp-monitor-v<version>.apk
 12. upload release APK artifact
 13. create git tag v<version>
 14. create GitHub Release with APK
```

## 6. 发版流程

### 6.1 常规发版（minor / patch）

1. 确认 `implement` 分支 CI 全绿。
2. 创建 PR：`implement` → `master`。
3. PR 描述包含 changelog 摘要。
4. 合并前确保 `pubspec.yaml` 版本号已更新。
5. 合并到 `master` 后，`release-build` 自动：
   - 构建 release APK
   - 创建 tag `v<version>`
   - 创建 GitHub Release
   - 上传 `temp-monitor-v<version>.apk`

### 6.2 紧急热修复发版（patch）

1. 从 `master` 切出 `hotfix/v<old-patch+1>-<描述>`。
2. 修改代码并**手动更新 `pubspec.yaml` 的 patch 版本**。
3. 直接 PR 到 `master`（跳过 `implement`）。
4. 合并后自动触发 `release-build`。
5. 合并完成后，将 `hotfix` 分支反向合并到 `implement`，保持分支同步。

### 6.3 预发布/内测

1. 从 `implement` 切出 `release/v<version>-beta`。
2. 手动触发 `workflow_dispatch` 构建 debug/release APK。
3. 不上传 GitHub Release，只保留 artifact 30 天。

## 7. 热修复与回滚

### 7.1 热修复触发条件

- 线上版本出现崩溃、数据丢失、无法扫描设备等严重问题
- 通知频繁误报或完全不报
- 后台服务被系统大量杀死

### 7.2 回滚策略

**Git 回滚（推荐）**

1. 在 GitHub Release 页面将 `latest` 指向上一个稳定 tag。
2. 从上一个稳定 tag 切出 `hotfix/v<x.x.x+1>-revert`，撤销有问题的提交。
3. 合并到 `master`，自动发布补丁版本。

**APK 替换**

- 不删除原 Release，但在 Release note 中标记：
  `DEPRECATED: use v<x.x.x+1>`

**数据库兼容性**

- 回滚必须保证数据库 schema 向下兼容。
- 不兼容迁移必须通过热修复版本号控制。

## 8. 工具与检查清单

### 8.1 每次修改前检查清单

- [ ] 是否已阅读 `AGENTS.md` 相关章节？
- [ ] 是否涉及 `lib/data/tables.dart` 或 DAO？如果是，确保 `.g.dart` 已更新并提交。
- [ ] 是否新增 BLE/位置/通知权限？同步更新 `AndroidManifest.xml` 和 `ios/Runner/Info.plist`。
- [ ] 是否修改扫描逻辑？区分 `scanForDiscovery` / `startDynamicScan` / `MockSensor`。
- [ ] 阈值变更后是否需要调用 `ScanService.restart()`？

### 8.2 每次 PR 检查清单

- [ ] PR 目标分支正确（`feat/*` → `implement`，`hotfix/*` → `master`）
- [ ] `pubspec.yaml` 版本号已更新（合并到 master 时）
- [ ] CI `build` job 通过
- [ ] 新增/修改的测试已覆盖
- [ ] 集成测试清单已执行或标注原因

### 8.3 AI 代理执行命令模板

```bash
# 生成文件一致性校验
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code

# 静态分析
flutter analyze --no-fatal-warnings

# 单元测试
flutter test --dart-define=APP_VERSION=$(grep '^version: ' pubspec.yaml | sed 's/version: //' | sed 's/\+.*//')

# 调试 APK 构建
flutter build apk --debug --dart-define=APP_VERSION=$(grep '^version: ' pubspec.yaml | sed 's/version: //' | sed 's/\+.*//')
```

## 9. 决策记录（ADR）

| 决策 | 选择 | 原因 |
|---|---|---|
| 分支模型 | GitHub Flow 简化版 | 与现有 `master`/`implement` 结构兼容，发布路径最短 |
| 本地是否编译 | 否 | 本地机器配置不足，重任务全部交给 GitHub Actions |
| `.g.dart` 是否提交 | 是 | 避免本地依赖 `build_runner`，CI 仅做一致性校验 |
| 发布触发 | `master` push 自动发布 | 与现有 `release-build` job 一致，减少人工操作 |
| 热修复分支 | 从 `master` 切出，合并后同步回 `implement` | 快速响应线上问题，同时保持分支同步 |

## 10. 参考文档

- `AGENTS.md`
- `CLAUDE.md`
- `docs/superpowers/plans/2026-06-12-xiaomi-bthome-monitor-plan.md`
- `docs/superpowers/design/2026-06-12-ui-design-spec.md`
- `.github/workflows/build_android.yml`
