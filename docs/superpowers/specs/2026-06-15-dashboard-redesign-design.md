# Dashboard Redesign — 仪表盘改版

## 背景

当前仪表盘（DashboardPage）作为设备卡片的二级页面存在，用户需在设备列表中点开才能看到数据。历史曲线是另一个独立页面，需要跳转查看。导航结构为底部三个 tab：设备、设置、调试。

## 目标

1. 仪表盘提升为一级页面，设为 App 默认首页
2. 仪表盘同页显示当前读数 + 历史曲线
3. 紧凑布局：温度、湿度、电量、信号集中在一个小卡片内
4. 多设备支持：通过横向滑动 PageView 切换设备
5. 保留设备管理页，用于添加/删除设备

## 导航结构

底部导航从 3 个 tab 改为 4 个 tab：

```
[仪表盘] [设备] [设置] [调试]
   ↑ 默认首页
```

- **仪表盘**：当前读数概览 + 历史曲线
- **设备**：已添加设备列表，添加/删除设备（原 `DevicesPage`，去掉 `_openDashboard` 跳转）
- **设置**：不变
- **调试**：不变

## 仪表盘布局

```
┌──────────────────────────────────────┐
│  ┌────────┐ ┌────────┐ ┌────────┐   │
│  │ATC_3F  │ │设备2   │ │设备3   │   │  ← PageView
│  │26.3°C  │ │24.1°C  │ │23.8°C  │   │
│  │61% · 98│ │55% · 95│ │70% ·100│   │
│  │-76dBm  │ │-65dBm  │ │-80dBm  │   │
│  └────────┘ └────────┘ └────────┘   │
│                                       │
│  ATC_3FB98D 的历史曲线               │
│  ┌──────────────────────────────┐    │
│  │    ╱╲     ╱╲               │    │
│  │   ╱  ╲   ╱  ╲             │    │
│  │  ╱    ╲ ╱    ╲            │    │
│  └──────────────────────────────┘    │
│         [24h] [7d] [30d]             │
└──────────────────────────────────────┘
```

### 紧凑设备卡片 (新 Widget: `DeviceOverviewCard`)

每张卡片显示一个设备的实时数据：

| 字段 | 位置 |
|---|---|
| 设备名 | 卡片左上角，小字 |
| 温度 | 大号字体，居中 |
| 湿度 · 电量 | 一行小字，在温度下方 |
| 信号 | 最底部，小字 |

卡片尺寸约 160×120，PageView 内横向滑动。当前页卡片居中，前后页露出边缘（`PageView.viewportFraction`）。

### 历史曲线

图表下方紧接，与当前选中的设备联动。PageView 滑动时：
- `onPageChanged` 触发设备切换
- DashboardCubit 重新加载该设备的历史数据
- 图表标题更新为当前设备名

曲线使用现有 `HistoryChart` widget，复用其温度/湿度双曲线、时间范围选择器。

## 数据流

### 状态管理

`DashboardCubit` 扩展：

```
class DashboardCubit extends Cubit<DashboardState> {
  List<Device> devices;        // 所有已添加设备
  int currentDeviceIndex;      // PageView 当前页索引
  Reading? latestReading;      // 当前设备最新读数
  List<Reading> history;       // 当前设备历史数据
  HistoryRange range;          // 当前选择的时间范围
}
```

### 实时更新

- ScanService 的 readingStream 继续推送实时数据
- DashboardCubit 监听 readingStream，过滤当前设备 ID
- 新读数到达时更新 `latestReading`
- 收到新读数时自动 append 到 `history` 列表，保持图表实时更新

### 设备切换

- PageView.onPageChanged → cubit.switchToDevice(index)
- 切换后：更新 currentDeviceIndex，重新加载历史数据
- 实时推送继续工作（filter 自动切换到新设备 ID）

## 涉及文件

| 文件 | 变更类型 |
|---|---|
| `lib/app.dart` | 修改导航栏为 4 tab，仪表盘为首页 |
| `lib/presentation/dashboard/dashboard_page.dart` | 完全重写——PageView + 历史曲线同页 |
| `lib/presentation/dashboard/dashboard_cubit.dart` | 扩展——多设备管理、历史数据加载 |
| `lib/presentation/devices/devices_page.dart` | 移除 `_openDashboard` 跳转 |
| `lib/widgets/device_overview_card.dart` | **新建**——紧凑设备概览卡片 |
| `lib/widgets/current_reading_card.dart` | 保留（历史曲线仍使用），或移除 |

## 未变更

- BLE 扫描逻辑（`ble_scanner.dart`）
- 数据解析（`custom_firmware_parser.dart`, `bthome_parser.dart`）
- 后台服务（`background_service.dart`）
- 设备管理（`devices_page.dart` 的扫描 drawer、添加设备逻辑）
- 设置页面
- 调试页面
