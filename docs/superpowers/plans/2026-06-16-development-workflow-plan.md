# temp_monitor 开发流程落地实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `docs/superpowers/specs/2026-06-16-development-workflow-design.md` 中的开发流程落地到 `temp_monitor` 项目，改造 CI/CD、补充模板、配置分支保护，使本地不编译的团队也能依赖 GitHub Actions 完成全部验证与发版。

**Architecture:** 在现有 `.github/workflows/build_android.yml` 上增量改造，增加 `.g.dart` 一致性检查、PR 触发范围、可选 PR 检查清单；新增 `.github/pull_request_template.md`；通过 GitHub 仓库设置启用分支保护；所有重任务继续由 GitHub Actions 执行。

**Tech Stack:** GitHub Actions, Flutter 3.22.0, drift/build_runner

---

## 文件变更总览

| 文件 | 操作 | 说明 |
|---|---|---|
| `.github/workflows/build_android.yml` | 修改 | 增加 `.g.dart` 一致性检查、扩展 PR 触发分支、增加 `pr-checklist` job、为 `release-build` 增加集成测试占位 |
| `.github/pull_request_template.md` | 创建 | PR 描述模板 |
| `lib/data/*.g.dart` | 验证/可能更新 | 确认已提交且与 drift 源文件一致 |

---

## 前置检查

### Task 0: 确认当前 `.g.dart` 文件已提交且最新

**Files:**
- Verify: `lib/data/app_database.g.dart`
- Verify: `lib/data/daos/devices_dao.g.dart`
- Verify: `lib/data/daos/readings_dao.g.dart`
- Verify: `lib/data/daos/settings_dao.g.dart`

- [ ] **Step 1: 列出已跟踪的生成文件**

Run:
```bash
git ls-files | grep '\.g\.dart'
```

Expected:
```
lib/data/app_database.g.dart
lib/data/daos/devices_dao.g.dart
lib/data/daos/readings_dao.g.dart
lib/data/daos/settings_dao.g.dart
```

- [ ] **Step 2: 确认生成文件与 drift 源文件一致（CI 会重做此检查）**

由于本地机器不编译，此步骤可跳过本地执行，直接依赖后续 CI 验证。若本地可临时运行 build_runner，则执行：

```bash
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code
```

Expected: 无 diff，命令退出码为 0。

---

## Task 1: 扩展 CI 触发分支与增加 `.g.dart` 一致性检查

**Files:**
- Modify: `.github/workflows/build_android.yml`

- [ ] **Step 1: 修改 `build` job 的触发条件**

将文件顶部 `on:` 部分替换为：

```yaml
on:
  push:
    branches: [master, implement, 'feat/**', 'fix/**', 'hotfix/**']
  pull_request:
    branches: [master, implement]
  workflow_dispatch:
```

- [ ] **Step 2: 在 `build` job 的代码生成步骤后增加一致性校验**

定位到现有步骤：

```yaml
      - name: Run code generation (drift)
        run: dart run build_runner build --delete-conflicting-outputs
```

在其后增加：

```yaml
      - name: Verify generated files are up-to-date
        run: |
          echo "Checking that drift generated files are committed and match source..."
          git diff --exit-code
```

- [ ] **Step 3: 在 `release-build` job 中同样增加一致性校验**

定位到现有步骤：

```yaml
      - name: Run code generation (drift)
        run: dart run build_runner build --delete-conflicting-outputs
```

在其后增加：

```yaml
      - name: Verify generated files are up-to-date
        run: |
          echo "Checking that drift generated files are committed and match source..."
          git diff --exit-code
```

- [ ] **Step 4: 提交变更**

Run:
```bash
git add .github/workflows/build_android.yml
git commit -m "ci: expand trigger branches and verify .g.dart consistency

- Trigger build on feat/*, fix/*, hotfix/* pushes
- Trigger build on PRs to implement branch
- Add git diff --exit-code check after build_runner to ensure generated files are committed"
```

---

## Task 2: 增加可选的 PR 检查清单 job

**Files:**
- Modify: `.github/workflows/build_android.yml`

- [ ] **Step 1: 在 `build` job 后新增 `pr-checklist` job**

在 `build` job 定义结束后、文件末尾前增加：

```yaml
  pr-checklist:
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Check PR title format
        run: |
          TITLE="${{ github.event.pull_request.title }}"
          echo "PR title: $TITLE"
          if echo "$TITLE" | grep -qE '^(feat|fix|refactor|test|docs|ci|chore)(\([^)]+\))?: .+'; then
            echo "PR title format OK"
          else
            echo "PR title must follow '<type>(<scope>): <subject>'"
            exit 1
          fi

      - name: Check version bump for master-bound PRs
        if: github.base_ref == 'master'
        run: |
          echo "Target branch is master; ensure pubspec.yaml version is updated if needed."
          # This is a reminder check; it does not fail the job automatically.
          echo "Manual check required: has pubspec.yaml version been bumped?"
```

- [ ] **Step 2: 提交变更**

Run:
```bash
git add .github/workflows/build_android.yml
git commit -m "ci: add lightweight pr-checklist job

- Validate conventional commit style in PR title
- Remind version bump check for PRs targeting master"
```

---

## Task 3: 为 release-build 增加集成测试占位步骤

**Files:**
- Modify: `.github/workflows/build_android.yml`

- [ ] **Step 1: 在 `release-build` job 的单元测试后增加集成测试占位**

定位到现有步骤：

```yaml
      - name: Run unit tests
        run: flutter test --dart-define=APP_VERSION=${{ steps.version.outputs.version }}
```

在其后增加：

```yaml
      - name: Integration test placeholder
        run: |
          echo "Integration tests require a connected Android device or emulator."
          echo "Run locally before release: flutter test integration_test/app_test.dart"
        continue-on-error: true
```

- [ ] **Step 2: 提交变更**

Run:
```bash
git add .github/workflows/build_android.yml
git commit -m "ci: add integration test placeholder to release-build

- Marks integration tests as required pre-release step
- Does not fail CI while no emulator/device is available"
```

---

## Task 4: 创建 PR 描述模板

**Files:**
- Create: `.github/pull_request_template.md`

- [ ] **Step 1: 创建 PR 模板文件**

Write the following to `.github/pull_request_template.md`:

```markdown
## 变更摘要

<!-- 用 1-3 句话说明本次变更解决了什么问题 -->

## 影响范围

<!-- 列出受影响的核心模块，例如：BLE 扫描、数据库、通知、UI -->

## 测试方式

<!-- 说明如何验证，例如：单元测试、真机测试、CI 通过 -->

## 检查清单

- [ ] 已阅读 `AGENTS.md` 相关章节
- [ ] 涉及 `lib/data/tables.dart` 或 DAO 时，`.g.dart` 已更新并提交
- [ ] 新增 BLE/位置/通知权限时，已同步更新 `AndroidManifest.xml` 和 `ios/Runner/Info.plist`
- [ ] 修改扫描逻辑时，已区分 `scanForDiscovery` / `startDynamicScan` / `MockSensor`
- [ ] 阈值变更后已考虑调用 `ScanService.restart()`
- [ ] 目标分支正确（`feat/*` → `implement`，`hotfix/*` → `master`）
- [ ] 合并到 `master` 时，`pubspec.yaml` 版本号已更新

## 关联文档

<!-- 链接对应的设计文档或 issue，例如： -->
<!-- - Design: docs/superpowers/specs/2026-06-16-development-workflow-design.md -->
```

- [ ] **Step 2: 提交变更**

Run:
```bash
git add .github/pull_request_template.md
git commit -m "docs: add pull request template

- Enforce change summary, impact scope, and testing notes
- Include project-specific checklist from AGENTS.md"
```

---

## Task 5: 配置 GitHub 分支保护

**Files:**
- 仓库设置（GitHub Web UI），无代码文件变更

> **Note:** 本任务仅通过 GitHub Web UI 配置，不修改仓库代码文件。

> **Status check prerequisite:** GitHub only shows status checks in the dropdown after they have run at least once on the target branch. If `build` or `pr-checklist` are not visible when configuring the rule, open a test PR against the target branch first so the checks appear in the UI.

- [ ] **Step 1: 为 `master` 分支启用保护规则**

在 GitHub 仓库页面操作：

1. 打开 `Settings` → `Branches` → `Add rule`
2. Branch name pattern: `master`
3. 勾选：
   - `Require a pull request before merging`
   - `Require status checks to pass before merging`
     - 搜索并勾选 `build`
     - 搜索并勾选 `pr-checklist`
   - `Require branches to be up to date before merging`
   - `Restrict pushes that create files larger than 100 MB`
   - `Block force pushes`
   - `Do not allow bypassing the above settings`
4. 保存

- [ ] **Step 2: 为 `implement` 分支启用保护规则**

1. 打开 `Settings` → `Branches` → `Add rule`
2. Branch name pattern: `implement`
3. 勾选：
   - `Require a pull request before merging`
   - `Require status checks to pass before merging`
     - 搜索并勾选 `build`
   - `Require branches to be up to date before merging`
   - `Restrict pushes that create files larger than 100 MB`
4. 保存

> **Note on `pr-checklist`:** The `pr-checklist` job enforces the conventional commit style in the PR title. The version-bump step for `master`-bound PRs is a non-blocking reminder; it logs a message and does not fail the job.

- [ ] **Step 3: 记录分支保护配置**

在 `.github/pull_request_template.md` 或本文档中无需额外文件变更，分支保护仅通过 GitHub UI 配置。

---

## Task 6: 验证改造后的 CI

**Files:**
- 依赖 GitHub Actions 运行，无本地代码变更

- [ ] **Step 1: 推送所有变更到 `implement` 分支**

Run:
```bash
git push origin master
```

> 如果当前在 `master` 分支且已有提交，直接推送会触发 `build` 和 `release-build`。由于本次改造只涉及 CI 和文档，风险较低。若希望先验证，可改为推送到一个临时 `ci/test-workflow` 分支。

替代验证方式（推荐）：
```bash
git checkout -b ci/verify-workflow implement
git push -u origin ci/verify-workflow
```

- [ ] **Step 2: 观察 GitHub Actions 运行结果**

1. 打开 GitHub 仓库 `Actions` 页面
2. 确认 `build` job 成功完成以下步骤：
   - `Run code generation (drift)`
   - `Verify generated files are up-to-date`
   - `Analyze`
   - `Run unit tests`
   - `Build debug APK`
3. 确认 `pr-checklist` job 在 PR 中触发并验证标题格式

- [ ] **Step 3: 创建一个测试 PR 验证模板和分支保护**

1. 从 `implement` 切出测试分支：`git checkout -b chore/test-pr-template implement`
2. 做一个无意义的空提交：`git commit --allow-empty -m "chore: test PR template and branch protection"`
3. Push 并创建 PR 到 `implement`
4. 确认 PR 描述自动填充模板
5. 确认 `build` 和 `pr-checklist` 检查出现
6. 验证完成后关闭该测试 PR 并删除分支

---

## Task 7: 更新项目文档索引

**Files:**
- Modify: `AGENTS.md`（可选，在 CI/CD 章节引用新流程文档）

- [ ] **Step 1: 在 `AGENTS.md` 第 7 节末尾增加开发流程参考**

在 `AGENTS.md` 第 7 节 `## 7. CI/CD` 末尾、第 8 节之前增加：

```markdown
### 开发流程规范

详细流程见 `docs/superpowers/specs/2026-06-16-development-workflow-design.md`，实施计划见 `docs/superpowers/plans/2026-06-16-development-workflow-plan.md`。

核心原则：

- 本地不编译，所有构建/测试/发布由 GitHub Actions 完成。
- `.g.dart` 生成文件必须提交到仓库，CI 会校验其与源文件一致。
- 功能分支 → `implement` → `master` → GitHub Release。
- 热修复从 `master` 切出，修复后同步回 `implement`。
```

- [ ] **Step 2: 提交变更**

Run:
```bash
git add AGENTS.md
git commit -m "docs(agents): reference new development workflow docs

- Link to workflow design and implementation plan
- Summarize core branch/release principles for future agents"
```

---

## 回滚计划

如果改造后的 CI 导致原有流程失败：

1. 立即检查失败日志，优先修复 `.github/workflows/build_android.yml`。
2. 若无法快速修复，可回滚到上一个稳定提交：
   ```bash
   git log --oneline -5
   git revert <bad-commit-sha>
   git push origin master
   ```
3. 回滚后重新创建修复 PR，避免直接 force-push 到受保护分支。

---

## 自审检查

- [ ] Spec coverage: 分支策略、.g.dart 一致性、PR 模板、分支保护、热修复流程均有对应任务。
- [ ] Placeholder scan: 无 TBD/TODO，所有代码片段和命令具体可执行。
- [ ] Type consistency: 文件路径、job 名称、分支名称与设计文档一致。
