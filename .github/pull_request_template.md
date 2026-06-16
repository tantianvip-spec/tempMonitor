## 变更摘要

<!-- 用 1-3 句话说明本次变更解决了什么问题 -->

## 影响范围

<!-- 列出受影响的核心模块，例如：BLE 扫描、数据库、通知、UI -->

## 测试方式

<!-- 说明如何验证，例如：单元测试、真机测试、CI 通过 -->

## 截图 / 视觉验证

<!-- UI 或视觉相关变更请附上截图、录屏或说明 -->

## 检查清单

- [ ] 已阅读 `AGENTS.md` 相关章节
- [ ] 涉及 `lib/data/tables.dart` 或 DAO 时，`.g.dart` 已更新并提交
- [ ] 新增 BLE/位置/通知权限时，已同步更新 `AndroidManifest.xml` 和 `ios/Runner/Info.plist`
- [ ] 修改扫描逻辑时，已区分 `scanForDiscovery` / `startDynamicScan` / `MockSensor`
- [ ] 阈值变更后已考虑调用 `ScanService.restart()`
- [ ] 新增/修改的代码已补充单元测试，或已说明无法覆盖的原因
- [ ] 涉及 BLE、后台服务、通知权限的变更已在真机/模拟器验证，或已说明原因
- [ ] 设计文档、`AGENTS.md` 或 `README` 已同步更新（如需要）
- [ ] 目标分支正确（`feat/*`、`fix/*` → `implement`；`hotfix/*` → `master`；`implement` → `master`）
- [ ] 合并到 `master` 时，`pubspec.yaml` 版本号已更新
- [ ] CI `build` job 已通过

## 关联文档

<!-- 链接对应的设计文档或 issue，例如： -->
<!-- - Design: docs/superpowers/specs/2026-06-16-development-workflow-design.md -->
