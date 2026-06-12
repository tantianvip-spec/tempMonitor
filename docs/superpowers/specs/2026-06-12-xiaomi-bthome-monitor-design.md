# 小米蓝牙温湿度计 2 BThome v2 监控 App 设计文档

**日期：** 2026-06-12  
**状态：** 待实现  
**作者：** Claude Code（与用户共同设计）

---

## 1. 项目目标

开发一款跨平台移动端 App，用于读取刷了第三方 BThome v2 固件的小米蓝牙温湿度计 2（LYWSD03MMC）的温湿度数据，后台持续记录历史数据，绘制趋势曲线，并在温度或湿度超出用户设定阈值时发送本地通知。

### 1.1 成功标准

- [ ] Android 手机能稳定扫描到设备广播并解析出正确温湿度。
- [ ] App 在后台或锁屏状态下仍能持续记录数据（Android 优先，iOS 尽力而为）。
- [ ] 历史曲线能按 24 小时 / 7 天 / 30 天展示温湿度趋势。
- [ ] 温度/湿度越界时发送本地通知，且避免重复打扰。
- [ ] 支持一键导出调试日志，便于远程定位问题。

---

## 2. 需求摘要

| 维度 | 决策 |
|---|---|
| 平台 | 跨平台（Android + iOS），优先保证 Android 体验 |
| 核心场景 | 后台持续监听并记录温湿度 |
| 数据存储 | 本地 SQLite，自动滚动保留 |
| 告警 | 温度/湿度越界时本地通知 |
| 设备数量 | 先实现 1 个，架构预留多设备扩展 |
| 扫描频率 | App 端可设置：1 秒 / 2 秒 / 5 秒，**默认 5 秒**；1 秒模式需提示高耗电 |
| 手动刷新 | 支持下拉刷新 |
| 构建方式 | GitHub Actions 自动构建 release APK |
| 调试方式 | 内置日志页，支持导出为文本文件 |

---

## 3. 技术栈

| 层级 | 技术 |
|---|---|
| 跨平台框架 | Flutter（Dart） |
| BLE 扫描 | `flutter_blue_plus` |
| BThome v2 解析 | 纯 Dart 模块 |
| 本地数据库 | `drift`（类型安全，带代码生成） |
| 状态管理 | `flutter_bloc`（事件/状态流转清晰） |
| 图表 | `fl_chart` |
| 本地通知 | `flutter_local_notifications` |
| 后台服务（Android） | `flutter_background_service` |
| CI / 构建 | GitHub Actions |

---

## 4. 架构设计

整体采用分层架构，模块间单向依赖：

```
┌─────────────────────────────────────────┐
│           Flutter App UI 层            │
│  （仪表盘、历史曲线、设备列表、设置页、   │
│    调试日志页）                         │
├─────────────────────────────────────────┤
│         业务逻辑层（BLoC/Provider）      │
│  （扫描调度、数据解析、阈值判断、通知）   │
├─────────────────────────────────────────┤
│           数据访问层（Repository）        │
│  （SQLite 读写、设备元数据、历史记录）    │
├─────────────────────────────────────────┤
│           平台服务层（Service）           │
│  BLE 扫描   │   本地通知   │   后台任务  │
├─────────────────────────────────────────┤
│           原生平台层                      │
│    Android Foreground Service            │
│    iOS  Background Fetch / BLE           │
└─────────────────────────────────────────┘
```

### 4.1 关键设计决策

1. **被动广播协议**：BThome v2 基于 BLE advertisement，无需维持连接，只需周期性扫描并解析广播包。
2. **前台服务保活（Android）**：通过 `flutter_background_service` 启动前台服务，显示常驻通知，系统不易杀死。
3. **iOS 合理预期**：iOS 支持 `bluetooth-central` 后台模式，可以后台接收 BLE 广播结果，但系统会节流/挂起应用，扫描结果以"机会性投递"为主，无法保证固定间隔。采用"允许中断、启动后恢复"策略。
4. **单一数据源**：SQLite 是 UI 和后台服务的唯一数据源，避免内存状态不一致。
5. **扫描频率与电量平衡**：默认扫描间隔为 5 秒；1 秒模式仅建议短期调试使用，选择时需明确提示高耗电风险。
6. **多设备预留**：数据库 schema 和设备模型从第一天起支持多设备，即使 UI 初期只展示一个。

---

## 5. 核心模块

| 模块 | 职责 | 说明 |
|---|---|---|
| `ble_scanner` | 扫描 BLE 广播、按 BThome Service UUID（0xFCD2）过滤、获取原始 bytes 和 RSSI | 依赖 `flutter_blue_plus` |
| `bthome_parser` | 解析 BThome v2 广播包，提取温度、湿度、电池、设备标识 | 纯 Dart，可独立单元测试 |
| `data_repository` | 本地数据库读写、设备元数据 CRUD、历史记录查询、滚动清理 | 依赖 `drift` |
| `threshold_engine` | 根据用户阈值判断是否越界，并实现状态去抖 | 纯 Dart，可独立单元测试 |
| `notification_service` | 发送本地通知 | 依赖 `flutter_local_notifications` |
| `history_ui` | 所有页面 UI 和图表 | 依赖 `fl_chart` |
| `debug_logger` | 分级日志、日志页展示、一键导出 | 纯 Dart + path_provider |

### 5.1 模块依赖关系

```
history_ui ──→ data_repository ──→ ble_scanner
                ↓                    ↓
        threshold_engine ←── bthome_parser
                ↓
        notification_service

所有模块 ──→ debug_logger（用于记录日志）
```

### 5.2 BThome v2 支持的 Object IDs

`bthome_parser` 至少支持以下 Object ID（BThome v2 规范）：

| Object ID | 含义 | 长度（字节） | 解析方式 | 单位 |
|---|---|---|---|---|
| 0x01 | 电池电量 | 1 | uint8 | % |
| 0x02 | 温度 | 2 | int16，小端，缩放 0.01 | °C |
| 0x03 | 湿度 | 2 | uint16，小端，缩放 0.01 | % |
| 0x2A | 温度（高精度/扩展） | 2 | int16，小端，缩放 0.01 | °C |
| 0x2B | 湿度（高精度/扩展） | 2 | uint16，小端，缩放 0.01 | % |

- 每个广播包由多个 TLV 段组成： `[Object ID][Value]`。
- 解析时按 ID 顺序读取，遇到未知 ID 可跳过或记录日志，不影响整体解析。
- 初始版本假设广播包为**未加密**。如果后续固件启用了 BThome 加密，需要额外增加绑定密钥输入和解密模块。

---

## 6. 数据流

一条温湿度读数的完整生命周期：

```
1. 小米温湿度计广播 BLE advertisement
        ↓
2. ble_scanner 扫描到广播包
   └── 按 Service UUID 0xFCD2 过滤
   └── 1 秒内同一设备去重
        ↓
3. bthome_parser 解析广播包
   └── 输出：device_id, temperature, humidity, battery, rssi, timestamp
   └── 过滤物理不可能值（如温度 > 80°C 或 < -40°C）
        ↓
4. data_repository 写入 SQLite
   └── 同时检查保留期限，清理过期数据
        ↓
5. 两条并行路径：
   ├──→ UI 层通过 Stream/State 自动刷新仪表盘和曲线
   └──→ threshold_engine 判断阈值
            ↓
        6. 状态变化时 → notification_service 发送本地通知
```

### 6.1 后台模式

```
App 进入后台
   ↓
Android：启动 Foreground Service，持续扫描并显示"正在监控温湿度"通知
iOS：声明 `bluetooth-central` 后台模式，系统会在有机会时投递扫描结果；用户重新打开 App 时从数据库恢复完整历史
   ↓
用户重新打开 App → 从数据库读取完整历史，无缝衔接
```

### 6.2 阈值通知去抖

- 只在"正常 → 越界"和"越界 → 正常"两种状态转换时发送通知。
- 持续越界期间不重复发送，避免 spam。

---

## 7. 数据库设计

### 7.1 表结构

```sql
-- 设备表
CREATE TABLE devices (
    id TEXT PRIMARY KEY,          -- 设备唯一标识（MAC 或 BThome 设备 ID）
    name TEXT,                    -- 用户可编辑的友好名称
    created_at INTEGER NOT NULL,  -- 创建时间（Unix 毫秒）
    last_seen_at INTEGER          -- 最后收到数据时间
);
-- 重新发现设备时执行 upsert：
-- INSERT INTO devices (...) VALUES (...)
-- ON CONFLICT(id) DO UPDATE SET last_seen_at = excluded.last_seen_at;

-- 读数表
CREATE TABLE readings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    temperature REAL NOT NULL,    -- 摄氏度
    humidity REAL NOT NULL,       -- 相对湿度 %
    battery INTEGER,              -- 电池电量 %（如果广播包含）
    rssi INTEGER,                 -- 信号强度
    recorded_at INTEGER NOT NULL, -- 记录时间（Unix 毫秒，UTC）
    FOREIGN KEY (device_id) REFERENCES devices(id)
);

CREATE INDEX idx_readings_device_time ON readings(device_id, recorded_at);
```

### 7.2 数据保留策略

- 默认保留 **30 天**。
- 每次写入新数据后，删除超过保留期限的旧数据。
- 用户可在设置页调整保留天数：7 天 / 30 天 / 90 天 / 永久。

---

## 8. 页面清单

| 页面 | 主要内容 | 优先级 |
|---|---|---|
| **仪表盘页** | 当前温度、湿度、电池、RSSI、设备名称、下拉刷新 | P0 |
| **历史曲线页** | 温度/湿度折线图，时间范围 24h / 7d / 30d | P0 |
| **设备列表页** | 已保存设备列表，点击进入仪表盘，支持扩展多设备 | P1 |
| **设置页** | 扫描频率、温度阈值、湿度阈值、数据保留天数 | P0 |
| **调试日志页** | 实时日志列表、日志级别过滤、一键导出 | P0 |

详细的视觉设计（配色、字体、图标、精确布局）在实施计划阶段细化。

---

## 9. 错误处理

| 场景 | 处理策略 |
|---|---|
| 蓝牙未开启 | 弹窗引导用户去系统设置打开；后台服务暂停扫描，等待蓝牙恢复 |
| 定位权限未授予（Android） | 首次启动请求 `Permission.locationWhenInUse`；若永久拒绝，提示"需要定位权限才能扫描蓝牙设备" |
| 蓝牙扫描权限缺失（Android 12+） | 运行时请求 `Permission.bluetoothScan` 和 `Permission.bluetoothConnect`；使用 `permission_handler` 插件管理；若拒绝则降级为仅前台监控或提示用户 |
| iOS 蓝牙后台权限缺失 | `Info.plist` 中声明 `NSBluetoothAlwaysUsageDescription` 和 `UIBackgroundModes: bluetooth-central`；用户拒绝时降级为仅前台监控 |
| 扫描不到设备 | 5 分钟无数据时界面显示提示；调试日志记录扫描事件 |
| BThome 解析失败 | 丢弃异常包并记录日志，不影响后续扫描 |
| 数据库写入失败 | 捕获异常、记录日志、尝试重建数据库、前台提示"数据保存异常" |
| 后台服务被系统杀死 | Android：前台服务 + `AndroidManifest.xml` 声明 `RECEIVE_BOOT_COMPLETED` 权限和 `BroadcastReceiver`，实现开机自启动；iOS：`bluetooth-central` 后台模式，打开 App 后自动恢复历史 |
| 异常读数 | 过滤超出物理合理范围的值，避免脏数据入库 |

---

## 10. 测试策略

### 10.1 单元测试（服务器本地可跑）

- `bthome_parser`：多种 BThome v2 广播包解析。
- `threshold_engine`：阈值判断和去抖逻辑。
- `data_repository`：CRUD、时间范围查询、滚动清理。

### 10.2 集成测试

- 使用 mock BLE 扫描数据，验证"扫描 → 解析 → 入库 → UI 更新"完整链路。
- 使用通知 mock 验证告警触发。

### 10.3 真机测试（用户配合）

| 测试项 | 用户操作 | 分析依据 |
|---|---|---|
| BLE 扫描 | 安装 APK，打开蓝牙和定位 | 用户反馈 + 导出日志 |
| 后台监控 | 锁屏 10 分钟 | 日志中扫描事件时间戳 |
| 历史曲线 | 运行一段时间后打开历史页 | 截图 + 日志 |
| 告警通知 | 设置会触发越界的阈值 | 用户反馈是否收到、是否重复 |

### 10.4 模拟设备模式

- 在设置页增加"模拟设备"开关。
- 开启后不再扫描真实蓝牙，而是定时生成假数据，用于无真机时验证 UI、数据库、图表、通知。

---

## 11. 构建与协作流程

1. **代码仓库**：用户创建 GitHub private repo，授权给我推送。
2. **开发环境**：我在腾讯云服务器写代码、跑单元测试。
3. **CI 构建**：GitHub Actions 配置 `flutter build apk --release`，自动产出 APK。
4. **真机测试**：用户下载 APK 安装到手机，用调试日志页导出日志发给我。
5. **问题修复**：我根据日志和反馈修改代码，重新触发构建。
6. **iOS 支持**：后续需要用户 Apple Developer 证书作为 GitHub Secrets 才能打 IPA。

---

## 12. 风险与限制

| 风险 | 影响 | 缓解措施 |
|---|---|---|
| iOS 后台扫描被系统限制 | 后台数据可能不完整 | 优先保证 Android；iOS 作为"打开即刷新"体验 |
| 无法使用真实 BLE 硬件本地调试 | 蓝牙相关问题需反复发版测试 | 完善日志、模拟设备模式、快速 CI 构建 |
| 不同第三方 BThome 固件广播内容差异 | 解析失败 | 日志中记录原始 bytes，便于适配 |
| BThome v2 加密广播 | 初始版本无法解析 | 本次范围假设未加密；若后续需要，增加绑定密钥输入和解密模块 |
| 电量消耗 | 用户可能觉得耗电 | 默认 5 秒扫描间隔，1 秒模式明确提示高耗电 |

---

## 13. 后续可扩展方向（不在本次范围）

- 多设备同时监控与对比。
- 数据导出 CSV / Excel。
- 云端同步与多手机共享。
- 自定义曲线时间范围。
- 暗黑模式 / 主题切换。

---

## 14. 待确认事项

- [x] 平台：跨平台 Flutter
- [x] 后台监控：需要
- [x] 数据存储：本地 + 滚动保留
- [x] 告警通知：需要
- [x] 设备数量：先 1 个，后续扩展
- [x] 扫描频率：App 端可设置
- [x] 下拉刷新：需要
- [x] 构建方式：GitHub Actions
- [x] 数据库选型：`drift`（类型安全，代码生成）
- [x] 状态管理选型：`flutter_bloc`（事件/状态清晰）
