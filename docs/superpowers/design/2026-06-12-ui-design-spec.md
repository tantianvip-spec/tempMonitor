# 小米温湿度计 2 监控 App — UI 视觉设计规范

**日期：** 2026-06-12  
**风格方向：** Scientific Instrument Minimalism（科学仪器极简主义）  
**设计基调：** 清晰、精确、克制、有实验室仪器的专业感，同时保持居家使用的亲和力。

---

## 1. 设计方向

### 1.1 概念

把 App 设计成一台**随身携带的精密温湿度记录仪**。界面参考：
- Braun 计算器 / Dieter Rams 产品
- 飞机驾驶舱仪表
- 现代实验室数字显示器

核心感受：数据为王，没有多余装饰。每个元素都有明确功能，大字号数字让人一眼读取，辅助信息退后成小字。

### 1.2 设计原则

1. **数据优先**：温湿度数字是界面绝对主角，其他信息缩小或弱化。
2. **高对比度**：深色背景 + 浅色文字 + 高饱和功能色，确保任何光线下可读。
3. **网格对齐**：所有卡片和文字严格对齐到 8pt 网格系统。
4. **一致性**：每个页面使用相同的间距、圆角、字体层级。
5. **少即是多**：不使用阴影、渐变背景、装饰性插画。

---

## 2. 色彩系统

### 2.1 深色模式（默认 / 推荐）

深色模式是主要体验，更符合"仪器屏幕"的感觉，也更省电。

| Token | Hex | 用途 |
|---|---|---|
| `bgPrimary` | `#0B0C0F` | 页面背景 |
| `bgSecondary` | `#14161B` | 卡片背景 |
| `bgTertiary` | `#1E2128` | 按钮、开关轨道、输入框背景 |
| `textPrimary` | `#F0F2F5` | 主标题、大数字 |
| `textSecondary` | `#8B919D` | 标签、辅助文字 |
| `textMuted` | `#5A6270` | 时间戳、分隔线文字 |
| `accentTemp` | `#FF9F43` | 温度相关：数字、图表线、图标 |
| `accentHumidity` | `#4DABF7` | 湿度相关：数字、图表线、图标 |
| `accentSuccess` | `#51CF66` | 正常状态、电量充足 |
| `accentWarning` | `#FFD43B` | 警告、电量低 |
| `accentDanger` | `#FF6B6B` | 越界告警、错误 |
| `border` | `#2A2E37` | 卡片边框、分隔线 |
| `gridLine` | `#1E2128` | 图表网格线 |

### 2.2 浅色模式

浅色模式作为可选项，用于明亮环境下的可读性。

| Token | Hex | 用途 |
|---|---|---|
| `bgPrimary` | `#F7F8FA` | 页面背景 |
| `bgSecondary` | `#FFFFFF` | 卡片背景 |
| `bgTertiary` | `#ECEEF2` | 按钮、开关轨道 |
| `textPrimary` | `#14161B` | 主文字 |
| `textSecondary` | `#5A6270` | 辅助文字 |
| `textMuted` | `#8B919D` | 时间戳 |
| `accentTemp` | `#E8590C` | 温度强调色 |
| `accentHumidity` | `#1971C2` | 湿度强调色 |
| `border` | `#DEE2E6` | 边框 |
| `gridLine` | `#ECEEF2` | 图表网格 |

### 2.3 语义色

- **正常范围**：数字使用对应功能色（温度 = 橙，湿度 = 蓝）
- **越界状态**：数字闪烁或变为 `accentDanger`，背景叠加淡淡红色
- **离线/无数据**：全部文字使用 `textMuted`

---

## 3. 字体系统

### 3.1 字体选择

| 用途 | 字体 | 备选 |
|---|---|---|
| 大数字 / 数据 | `JetBrains Mono` | `Roboto Mono` |
| 标题 / 标签 | `Manrope` | `Inter` |
| 辅助说明 | `Manrope` | `Inter` |

**Flutter 实现：** 使用 `google_fonts` 包。

```yaml
dependencies:
  google_fonts: ^6.2.1
```

```dart
import 'package:google_fonts/google_fonts.dart';

textTheme: TextTheme(
  displayLarge: GoogleFonts.jetBrainsMono(
    fontSize: 72,
    fontWeight: FontWeight.w300,
    letterSpacing: -2,
    color: colorScheme.onSurface,
  ),
  titleLarge: GoogleFonts.manrope(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  ),
  bodyMedium: GoogleFonts.manrope(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  ),
  labelSmall: GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
  ),
)
```

### 3.2 字号层级

| 层级 | 字号 | 字重 | 用途 |
|---|---|---|---|
| `displayLarge` | 72px | 300 | 仪表盘主数值 |
| `displayMedium` | 48px | 300 | 次要大数值 |
| `titleLarge` | 20px | 600 | 页面标题 |
| `titleMedium` | 16px | 600 | 卡片标题 |
| `bodyMedium` | 14px | 400 | 正文、说明 |
| `labelSmall` | 11px | 500 | 标签、单位、时间戳 |

### 3.3 数字显示

- 大数字使用等宽字体，避免变化时抖动。
- 温度/湿度数值带一位小数：`25.3°C` / `62.0%`
- 单位单独使用 `labelSmall` 样式，颜色为 `textSecondary`

---

## 4. 间距与布局

### 4.1 基础间距

| Token | 值 | 用途 |
|---|---|---|
| `xs` | 4px | 图标与文字间距 |
| `sm` | 8px | 紧凑内边距 |
| `md` | 16px | 标准卡片内边距 |
| `lg` | 24px | 页面水平边距 |
| `xl` | 32px | 区块间距 |
| `xxl` | 48px | 大区块分隔 |

### 4.2 页面边距

- 移动端水平边距：`24px`（小屏可降至 `16px`）
- 卡片间距：`16px`
- 卡片内部内边距：`20px`

### 4.3 圆角

| Token | 值 | 用途 |
|---|---|---|
| `radiusSm` | 8px | 按钮、输入框 |
| `radiusMd` | 12px | 小卡片 |
| `radiusLg` | 16px | 大卡片、页面容器 |
| `radiusPill` | 999px | 标签、开关、分段选择器 |

---

## 5. 组件规范

### 5.1 数据卡片（Reading Card）

用于仪表盘显示温度、湿度、电量、信号。

```
┌─────────────────────────────┐
│  ICON    LABEL              │  ← 标签 11px，textSecondary
│                             │
│  25.3°C                     │  ← 数值 72px，功能色
│                             │
│  更新于 14:32               │  ← 时间戳 11px，textMuted
└─────────────────────────────┘
```

- 背景：`bgSecondary`
- 边框：1px solid `border`
- 圆角：`radiusLg` (16px)
- 内边距：20px
- 图标：24px，颜色与数值一致
- 标签：全大写，字间距 0.5px

### 5.2 主数据卡片（Hero Card）

仪表盘顶部的温度/湿度大卡片，占据整行宽度。

```
┌──────────────────────────────────────┐
│  温度                          湿度   │
│                                      │
│  25.3°C              62.0%          │
│  ↑ 0.5              ↓ 2.1           │  ← 与上一次读数的变化
│                                      │
│  设备：客厅      信号 -65 dBm        │
└──────────────────────────────────────┘
```

- 双列布局，温度在左，湿度在右
- 数值使用 `displayLarge` (72px)
- 变化趋势用小箭头 + 数值，颜色与功能色一致

### 5.3 开关（Switch）

```
┌──────────────────────────────────────┐
│  模拟设备模式                  [○──]  │
│  不扫描真实蓝牙，生成测试数据         │
└──────────────────────────────────────┘
```

- 轨道高度：28px，宽度：52px
- 关闭：轨道 `bgTertiary`，圆点 `textMuted`
- 开启：轨道 `accentHumidity`，圆点 `textPrimary`
- 无阴影

### 5.4 滑块（Slider）

用于阈值设置。

- 轨道高度：4px
- 激活段颜色：`accentTemp`
- 未激活段颜色：`bgTertiary`
- 滑块大小：20px 圆形
- 滑块颜色：`textPrimary`，边框 2px `accentTemp`

### 5.5 分段选择器（Segmented Button）

用于历史曲线时间范围切换。

```
┌─────────┬─────────┬─────────┐
│  24h    │   7d    │  30d    │
└─────────┴─────────┴─────────┘
```

- 容器：`bgTertiary`，圆角 `radiusPill`
- 选中项：`bgSecondary` + `textPrimary` + 边框
- 未选中：`textSecondary`
- 高度：36px

### 5.6 列表项（List Tile）

用于设备列表、设置页。

```
┌──────────────────────────────────────┐
│  ICON  主标题                  箭头  │
│        副标题                        │
└──────────────────────────────────────┘
```

- 高度：64px
- 左侧图标：24px，颜色 `textSecondary`
- 主标题：`bodyMedium`，`textPrimary`
- 副标题：`labelSmall`，`textSecondary`

### 5.7 图表（History Chart）

- 背景透明，使用 `bgSecondary` 卡片包裹
- 温度线：`accentTemp`，线宽 2px
- 湿度线：`accentHumidity`，线宽 2px
- 网格线：`gridLine`，虚线
- 坐标轴文字：`labelSmall`，`textMuted`
- 无填充区域（保持简洁）
- 触摸提示：垂直参考线 + 悬浮数据标签

---

## 6. 页面布局

### 6.1 仪表盘页（Dashboard）

```
┌──────────────────────────────────────┐
│  ←  客厅                  ⋮          │  ← AppBar，设备名居中
├──────────────────────────────────────┤
│                                      │
│  温度              湿度              │
│  25.3°C            62.0%            │
│  ↑ 0.5            ↓ 2.1             │
│                                      │
│  设备在线 · 5秒前更新                 │
│                                      │
├──────────────────────────────────────┤
│  电量              信号              │
│  85%               -65 dBm          │
│                                      │
├──────────────────────────────────────┤
│  [查看历史曲线]                      │
│                                      │
│  最近记录                            │
│  14:30  25.1°C  61.8%               │
│  14:25  24.9°C  62.5%               │
│  14:20  24.8°C  63.1%               │
└──────────────────────────────────────┘
```

- 顶部 Hero 卡片占 2/3 视觉重心
- 电量/信号为二等分卡片
- 底部"查看历史曲线"为大按钮
- 下拉刷新时显示简洁 loading indicator

### 6.2 历史曲线页（History）

```
┌──────────────────────────────────────┐
│  ←  历史曲线                         │
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │
│  │      温度/湿度折线图            │  │
│  │                                │  │
│  │   ═══════════════════════      │  │
│  │   ·······················      │  │
│  │                                │  │
│  └────────────────────────────────┘  │
│                                      │
│     [24h]  [7d]  [30d]               │  ← 分段选择器居中
│                                      │
│  统计                                │
│  最高 28.5°C    最低 22.1°C          │
│  平均 25.3°C    平均湿度 61.2%       │
└──────────────────────────────────────┘
```

- 图表卡片占页面主要区域
- 时间选择器位于图表下方居中
- 底部统计使用 2x2 网格

### 6.3 设置页（Settings）

```
┌──────────────────────────────────────┐
│  ←  设置                             │
├──────────────────────────────────────┤
│                                      │
│  扫描                                │
│  扫描频率                5 秒  ▶     │
│                                      │
│  数据                                │
│  数据保留天数            30 天 ▶     │
│                                      │
│  告警阈值                            │
│  温度范围          0.0 ~ 40.0°C     │
│  湿度范围          20.0 ~ 80.0%     │
│                                      │
│  调试                                │
│  模拟设备模式            [○──]       │
│                                      │
│  关于                                │
│  调试日志                   ▶        │
└──────────────────────────────────────┘
```

- 分组标题：`labelSmall`，全大写，`textSecondary`
- 每个分组下方带 1px 分隔线
- 阈值设置点击后弹出滑块对话框

### 6.4 设备列表页（Devices）

```
┌──────────────────────────────────────┐
│  设备列表                            │
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │
│  │  🌡  客厅                  ▸   │  │
│  │     5秒前 · 25.3°C · 62.0%    │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │  🌡  卧室                  ▸   │  │
│  │     1分钟前 · 24.8°C · 63.1%  │  │
│  └────────────────────────────────┘  │
│                                      │
│     [ + 添加设备 ]                   │
└──────────────────────────────────────┘
```

- 每个设备一行卡片
- 卡片内显示设备名、最后读数、时间
- 初始版本只展示一个设备，但结构支持多设备

### 6.5 调试日志页（Debug Log）

```
┌──────────────────────────────────────┐
│  ←  调试日志      [复制] [清空]      │
├──────────────────────────────────────┤
│                                      │
│  ● 14:32:01  [BLE] 扫描到设备 A4...  │
│  ● 14:32:01  [Parser] 25.3°C 62.0%  │
│  ● 14:31:56  [Repo] 保存读数         │
│  ○ 14:31:51  [BG] 后台扫描运行中     │
│                                      │
└──────────────────────────────────────┘
```

- 日志按时间倒序排列
- 不同级别用不同颜色圆点：Error=红，Warning=黄，Info=蓝，Debug=灰
- 顶部操作按钮：复制全部、清空

---

## 7. 图标系统

使用 `Phosphor Icons` 或 `Material Symbols`，推荐 Phosphor 的 **regular/duotone** 风格，线条简洁、科技感强。

| 用途 | 图标 | Phosphor 名称 |
|---|---|---|
| 温度 | 🌡 | `thermometer` |
| 湿度 | 💧 | `drop` |
| 电量 | 🔋 | `battery-full` |
| 信号 | 📶 | `wifi-high` |
| 设备 | 📟 | `device-mobile` |
| 历史 | 📈 | `chart-line-up` |
| 设置 | ⚙️ | `gear` |
| 调试 | 🐛 | `bug` |
| 复制 | 📋 | `copy` |
| 清空 | 🗑 | `trash` |
| 箭头 | ▸ | `caret-right` |
| 趋势上升 | ↑ | `arrow-up` |
| 趋势下降 | ↓ | `arrow-down` |

**Flutter 实现：** 使用 `phosphor_flutter` 包。

```yaml
dependencies:
  phosphor_flutter: ^2.1.0
```

---

## 8. 动效与微交互

### 8.1 页面转场

- 使用 Flutter 默认的 `CupertinoPageRoute` 风格滑动转场，符合 iOS/Android 原生习惯。
- 页面进入：从右向左滑入，200ms，ease-out。

### 8.2 数字变化

- 温度/湿度数值变化时，不使用动画（等宽字体直接跳变，更像仪器）。
- 如需动画，使用 150ms 的计数器动画，但保持简洁。

### 8.3 卡片按压

- 可点击卡片按下时：`bgTertiary`，缩放 0.98，100ms。
- 释放后恢复。

### 8.4 开关切换

- 圆点滑动 200ms，ease-in-out。
- 轨道颜色渐变 200ms。

### 8.5 加载状态

- 下拉刷新：顶部显示 2px 的 `accentHumidity` 进度线。
- 页面 loading：居中的简洁圆环，颜色 `accentHumidity`。

### 8.6 告警动效

- 越界时，数值以 `accentDanger` 颜色短暂闪烁 2 次（每次 300ms）。
- 通知弹窗使用系统默认通知，不自定义。

---

## 9. 暗黑模式实现

- 使用 Flutter `ThemeData` 的 `brightness: Brightness.dark`。
- 所有颜色通过 `ColorScheme` 定义，UI 组件从 `Theme.of(context)` 取色。
- 浅色模式通过切换 `brightness: Brightness.light` 和对应 ColorScheme 实现。
- 默认启动为深色模式。

```dart
ColorScheme _darkScheme() => const ColorScheme.dark(
  surface: Color(0xFF0B0C0F),
  surfaceContainerHighest: Color(0xFF14161B),
  onSurface: Color(0xFFF0F2F5),
  onSurfaceVariant: Color(0xFF8B919D),
  outline: Color(0xFF2A2E37),
  primary: Color(0xFF4DABF7),
  secondary: Color(0xFFFF9F43),
  error: Color(0xFFFF6B6B),
);
```

---

## 10. 实现优先级

1. **P0 - 核心视觉**：深色 ColorScheme + 字体系统 + 数据卡片样式
2. **P0 - 仪表盘**：Hero 卡片 + 电量/信号卡片 + 下拉刷新
3. **P0 - 历史曲线**：图表样式 + 分段选择器
4. **P0 - 设置页**：列表分组 + 开关 + 滑块对话框
5. **P1 - 设备列表**：卡片列表样式
6. **P1 - 调试日志**：日志行样式 + 顶部操作栏
7. **P2 - 浅色模式**：ColorScheme 切换

---

## 11. 设计文件

- 本规范：`docs/superpowers/design/2026-06-12-ui-design-spec.md`
- 对应的实现计划：`docs/superpowers/plans/2026-06-12-xiaomi-bthome-monitor-plan.md`

实施时，UI 相关任务（Task 12-17）需严格参考本规范。
