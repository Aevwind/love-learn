# 📘 《学霸锁 (StudyLock)》产品需求与技术架构规格说明书

| 文档版本 | 修订日期 | 适用平台 | 核心技术栈 | 状态 |
| :--- | :--- | :--- | :--- | :--- |
| **v1.0.0** | 2026-11-10 | Android / iOS / Tablet / Desktop | Flutter 3.x + Drift (SQLite) + Riverpod + Pigeon | 定稿可开发 |

---

## 1. 产品概述与核心价值 (Product Overview)

**《学霸锁 (StudyLock)》** 是一款跨平台、强管控的防沉迷学习锁应用。通过监控受控娱乐应用（黑名单）的累计或独立使用时长，在达到设定阈值时弹出**系统级全屏答题拦截页**。用户必须完成指定数量的题目（支持选择、填空、听力，并融合错题本加权抽取与防盲猜机制）后方可继续使用设备；同时配备应用启动密码锁与系统级防卸载保护，形成严密的自律与监督闭环。

---

## 2. 功能需求明细 (Functional Requirements)

### 2.1 应用监控与防沉迷触发模块
1. **黑名单管理与分组：**
   * 获取设备已安装非系统应用列表，支持按类别（游戏娱乐、短视频、社交社区）分组勾选或一键全选。
2. **双模式计时引擎：**
   * **累计计时模式（默认）：** 黑名单内所有受控应用共享同一个周期计时器（例如：刷抖音 15 分钟 + 玩王者荣耀 15 分钟 = 触发 30 分钟限制）。
   * **独立计时模式：** 每个受控应用单独计算使用时长，支持为特定重度沉迷应用设置专属时长阈值。
3. **人性化防打断预警（60秒缓冲）：**
   * 距离拦截触发还剩 **60 秒** 时，在屏幕顶部弹出轻量级非阻塞悬浮横幅（显示实时倒计时与当前受控应用），防止用户在游戏团战或编辑重要消息时突然中断。
4. **全屏霸屏拦截与豁免机制：**
   * 倒计时归零后，立即唤起最高优先级的全屏答题界面，屏蔽物理返回键、全面屏侧滑手势及桌面端键盘 `Esc`。
   * **系统白名单豁免：** 拦截期间保留系统紧急电话接听与拨打通道；提供每日 1 次的“紧急跳过（需强制经过 5~10 秒深呼吸冷静倒计时）”功能。

### 2.2 答题闯关与防盲猜模块

| 功能特性 | 详细业务规则与交互逻辑 |
| :--- | :--- |
| **通关条件配置** | 支持配置每次拦截需**“连续答对 $N$ 题”**或**“累计答对 $N$ 题”**（默认 $N=3$）方可解锁下一周期。 |
| **多题型支持** | • **单选/多选题：** 每次渲染时使用 **Fisher-Yates 洗牌算法**随机打乱选项顺序，防止背诵选项位置。<br>• **填空题：** 支持忽略大小写、忽略首尾空格、支持**同义词/多答案匹配**（以 `|` 分隔，如 `to|归因于`）。<br>• **英语听力题：** 支持播放题库内置音频（MP3/WAV）或调用**系统原生 TTS** 实时朗读（格式 `tts:word`），内置 $1.0\times / 0.75\times$ 慢速切换与重播。 |
| **防盲猜冷却惩罚** | 1. **强制冷却锁：** 答错后卡片触发红色震动反馈，自动展开详细解析面板，并将“下一题/提交”按钮**强制锁定倒计时 5 秒**，强迫用户阅读解析。<br>2. **错题追加惩罚（可选）：** 答错 1 题，本次通关所需答对题数 $+1$。 |
| **错题本联动抽取** | 答错题目自动标记加入**错题本**并提高抽题权重分（Weight Score）；每次触发拦截时，默认按 **$60\%$ 错题 + $40\%$ 新题** 的比例混合加权抽取；连续答对 3 次后自动移出错题本。 |

### 2.3 题库管理与高扩展导入协议
1. **多题库混出：** 支持同时启用多个题库（如“六级高频词汇” + “TypeScript 面试题”），支持按标签与难度筛选。
2. **外部手动导入：** 支持导入标准 **JSON 文件**、**CSV 表格**及包含多媒体资源的 **ZIP 题库包**（内含 `questions.json` 与 `media/` 目录）。
3. **标准化题库导入 JSON Schema 规范：**

```json
{
  "bank_name": "雅思核心听力与词汇",
  "category": "english",
  "version": "1.0.0",
  "questions": [
    {
      "id": "q_cet6_001",
      "type": "listening",
      "difficulty": 3,
      "stem": "请听单词发音，选择正确的中文释义：",
      "audio_source": "tts:ephemeral",
      "payload": {
        "options": ["转瞬即逝的；短暂的", "永恒的；不朽的", "复杂的；难懂的", "盛行的；普遍的"],
        "shuffle": true,
        "default_speed": 1.0
      },
      "answer": [0],
      "explanation": "ephemeral [ɪˈfemərəl] adj. 短暂的，朝生暮死的。记忆法：e(出) + phemer(一天) -> 只活一天的。",
      "tags": "高频,形容词"
    },
    {
      "id": "q_cet6_002",
      "type": "fill_blank",
      "difficulty": 2,
      "stem": "We attribute our success ______ hard work.",
      "payload": {
        "case_sensitive": false,
        "placeholder": "请输入正确的介词"
      },
      "answer": ["to|归因于"],
      "explanation": "attribute...to... 为固定搭配，意为“把……归因于……”。",
      "tags": "固定搭配,介词"
    }
  ]
}
```

### 2.4 安全验证与系统级防卸载模块
1. **应用启动与配置密码锁：**
   * 进入本应用修改黑名单、暂停守护、调整时长策略或题库开关时，必须验证 **6 位数字 PIN 码**。
   * **禁用默认生物识别：** 默认关闭本机指纹/面容快捷解锁（防被监督者本人用自己指纹一键解开）。
   * **加密与防暴力破解：** 密码采用 `PBKDF2 / SHA-256 + 随机盐值(Salt)` 哈希后存入系统安全区（Keystore / Keychain）；连续输错 5 次强制锁定 10 分钟。
2. **系统级防绕过与防卸载：**
   * **连带锁定系统设置：** 自动监控系统的“设置 (Settings)”与“软件包安装程序”，当试图强行停止或卸载本应用时，直接弹出密码验证框或答题拦截框。
   * **设备管理器保护：** 引导激活 Android `DevicePolicyManager` / iOS `FamilyControls`，未在应用内验证密码解除激活前，系统层面禁止卸载。
   * **防篡改系统时间：** 计时逻辑统一使用系统开机相对单调时间（如 `SystemClock.elapsedRealtime()`），修改手机系统时间无效。

---

## 3. UI/UX 交互与多屏幕自适应规范 (Multi-Screen Responsive Design)

采用一套代码自适应 **手机竖屏、折叠屏/小平板、大平板横屏/桌面端** 三种屏幕形态，并全面适配刘海屏安全区（`SafeArea`）与填空题软键盘弹出防遮挡（`viewInsets.bottom`）：

| 屏幕断点形态 | 主设置控制台布局 (`Main Console`) | 全屏答题拦截页布局 (`Quiz Interceptor`) |
| :--- | :--- | :--- |
| **📱 手机竖屏 (`< 600px`)** | **单栏流式布局 + 底部 BottomNavigationBar**：包含“监控策略”、“题库与错题”、“安全防卸载”三大 Tab。 | **顶部进度条 + 居中限宽卡片 (`maxWidth: 520px`) + 底部固定提交栏**，适配单手拇指操作。 |
| **📖 折叠屏 / 小平板 (`600px ~ 900px`)** | **左侧紧凑 NavigationRail + 右侧双列网格**：左列管理受控应用，右列管理题库开关与计时策略。 | 居中悬浮大卡片，背景采用深色毛玻璃模糊，防止选项按钮过度拉伸。 |
| **💻 大平板横屏 / 桌面端 (`>= 900px`)** | **三栏仪表盘 (Dashboard)**：左侧完整导航栏 + 中间核心配置区 + 右侧常驻“错题统计与今日拦截报表”。 | **左右分栏布局 (`maxWidth: 1100px`)**：左栏展示进度、题干与听力控制器；右栏展示选项列表与解析面板，支持**键盘快捷键（`1/2/3/4` 选答案，`Enter` 提交）**。 |

---

## 4. 数据库表结构设计 (SQLite / Drift Schema)

采用 **结构化关系表 + JSON 动态负载** 混合设计，兼顾查询性能与新题型扩展性：

```sql
PRAGMA foreign_keys = ON;

-- 1. 题库表 (question_banks)
CREATE TABLE question_banks (
    id TEXT PRIMARY KEY,                  -- 题库唯一ID，如 'bank_cet6_2026'
    name TEXT NOT NULL,                   -- 题库名称
    description TEXT,                     -- 题库简介
    category TEXT DEFAULT 'general',      -- 分类：'english', 'code', 'math'
    version TEXT DEFAULT '1.0.0',         -- 版本号
    source_type TEXT NOT NULL,            -- 来源：'builtin'(内置), 'imported'(手动导入)
    is_enabled INTEGER DEFAULT 1,         -- 是否参与拦截抽题：1=启用, 0=停用
    question_count INTEGER DEFAULT 0,     -- 题目总数缓存
    media_base_path TEXT,                 -- 本地解压音频/图片目录路径
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- 2. 题目主表 (questions)
CREATE TABLE questions (
    id TEXT PRIMARY KEY,                  -- 题目唯一ID
    bank_id TEXT NOT NULL,                -- 关联 question_banks.id
    type TEXT NOT NULL,                   -- 题型：'single_choice', 'multi_choice', 'fill_blank', 'listening'
    difficulty INTEGER DEFAULT 1,         -- 难度星级：1~5
    stem TEXT NOT NULL,                   -- 题干文本
    audio_source TEXT,                    -- 听力源：'tts:word' 或 'file:001.mp3'
    image_url TEXT,                       -- 配图相对路径
    payload_json TEXT NOT NULL,           -- 题型专属配置 JSON (如 options 数组、case_sensitive 等)
    answer_json TEXT NOT NULL,            -- 标准答案 JSON (如 [0] 或 ["to|归因于"])
    explanation TEXT,                     -- 答案详细解析（答错强制冷却5秒时展示）
    tags TEXT,                            -- 逗号分隔标签
    created_at INTEGER NOT NULL,
    FOREIGN KEY (bank_id) REFERENCES question_banks(id) ON DELETE CASCADE
);

CREATE INDEX idx_questions_bank_type ON questions(bank_id, type);

-- 3. 用户答题记录与错题本表 (user_question_records)
CREATE TABLE user_question_records (
    question_id TEXT PRIMARY KEY,         -- 关联 questions.id
    is_in_mistake_book INTEGER DEFAULT 0, -- 是否在错题本中：1=是, 0=否
    total_attempts INTEGER DEFAULT 0,     -- 历史总作答次数
    wrong_attempts INTEGER DEFAULT 0,     -- 历史答错总次数
    consecutive_correct INTEGER DEFAULT 0,-- 当前连续答对次数（满3次自动移出错题本）
    weight_score REAL DEFAULT 100.0,      -- 抽题权重分：答错 +50，答对 -20
    last_answered_at INTEGER,
    next_review_at INTEGER,
    FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
);

CREATE INDEX idx_records_mistake_weight ON user_question_records(is_in_mistake_book, weight_score DESC);

-- 4. 受控应用名单与计时状态表 (monitored_apps)
CREATE TABLE monitored_apps (
    package_name TEXT PRIMARY KEY,        -- 应用包名，如 'com.tencent.tmgp.sgame'
    app_name TEXT NOT NULL,               -- 应用名称
    category TEXT DEFAULT 'entertainment',-- 分类：'game', 'video', 'social'
    is_monitored INTEGER DEFAULT 1,       -- 是否开启监控：1=开启, 0=暂停
    custom_limit_minutes INTEGER,         -- 独立计时模式下的专属限制时长
    today_used_seconds INTEGER DEFAULT 0, -- 今日已累计使用秒数
    current_cycle_seconds INTEGER DEFAULT 0, -- 当前拦截周期内已用秒数（通关后清零）
    last_active_at INTEGER
);

-- 5. 全局安全与防沉迷策略配置表 (app_security_config - 单行表)
CREATE TABLE app_security_config (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    timer_mode TEXT DEFAULT 'cumulative', -- 'cumulative'(共享累计) / 'independent'(独立计时)
    trigger_limit_minutes INTEGER DEFAULT 30,
    warning_before_seconds INTEGER DEFAULT 60,
    pass_required_count INTEGER DEFAULT 3,
    wrong_cooldown_seconds INTEGER DEFAULT 5,
    wrong_penalty_add INTEGER DEFAULT 0,
    mistake_priority_ratio REAL DEFAULT 0.6,
    is_password_enabled INTEGER DEFAULT 1,
    password_hash TEXT,                   -- SHA-256 加盐哈希值
    password_salt TEXT,                   -- 随机加密盐值
    failed_unlock_attempts INTEGER DEFAULT 0,
    lockout_until_timestamp INTEGER DEFAULT 0,
    protect_system_settings INTEGER DEFAULT 1
);
```

### 智能混合加权抽题 SQL 算法
1. **第一阶段（按比例抽取错题本高权重错题，如 $60\%$）：**
```sql
SELECT q.* FROM questions q
JOIN question_banks b ON q.bank_id = b.id
JOIN user_question_records r ON q.id = r.question_id
WHERE b.is_enabled = 1 AND r.is_in_mistake_book = 1
ORDER BY (r.weight_score * ABS(RANDOM() / 9223372036854775807.0)) DESC
LIMIT :mistakeCount;
```
2. **第二阶段（从已启用题库随机补齐剩余新题）：**
```sql
SELECT q.* FROM questions q
JOIN question_banks b ON q.bank_id = b.id
WHERE b.is_enabled = 1 AND q.id NOT IN (:alreadyPickedIds)
ORDER BY RANDOM()
LIMIT :remainingCount;
```

---

## 5. Flutter 跨平台工程结构与技术架构 (Technical Architecture)

### 5.1 核心依赖选型 (`pubspec.yaml`)
* **状态管理：** `flutter_riverpod` + `riverpod_annotation`
* **本地数据库：** `drift` + `sqlite3_flutter_libs`
* **不可变模型与序列化：** `freezed` + `json_serializable`
* **跨平台强类型通信：** `pigeon`
* **安全存储与加密：** `flutter_secure_storage` + `crypto`
* **语音合成与音频播放：** `flutter_tts` + `just_audio`

### 5.2 各平台底层拦截能力映射表
| 系统能力 | Android 原生实现 (`Kotlin`) | iOS 原生实现 (`Swift`) | Windows / macOS 桌面端 |
| :--- | :--- | :--- | :--- |
| **前台应用监控** | `AccessibilityService` 监听窗口切换或 `UsageStatsManager` | Screen Time API (`DeviceActivityMonitor` 扩展) | `GetForegroundWindow` / `NSWorkspace` |
| **全屏霸屏拦截** | `SingleInstance` 全屏拦截 Activity 或 `SYSTEM_ALERT_WINDOW` | `ManagedSettings` 框架 + `ShieldConfiguration` | `AlwaysOnTop` + 无边框全屏置顶窗口 |
| **防卸载与安全** | `DevicePolicyManager` (设备管理器) + `Keystore` | `FamilyControls` 授权防删 + `Keychain` | 系统守护服务 (Service / LaunchAgent) |

### 5.3 项目目录树 (Feature-First + Clean Architecture + 双入口设计)
```text
studylock_app/
├── android/                         # Android 原生监控服务、全屏拦截 Activity、设备管理器
├── ios/                             # iOS Screen Time API 扩展 (DeviceActivity / Shield)
├── windows/ & macos/                # 桌面端窗口置顶钩子
├── pigeons/
│   └── native_monitor_api.dart      # Pigeon 跨语言强类型通信协议定义
├── assets/
│   ├── builtin_banks/               # 内置默认题库 JSON
│   └── audio/                       # 交互音效
└── lib/
    ├── main.dart                    # 【入口1】主设置控制台入口
    ├── main_overlay.dart            # 【入口2】全屏答题拦截器独立轻量级入口 (@pragma('vm:entry-point'))
    ├── core/
    │   ├── database/                # Drift 数据库定义、TypeConverter 与 Migration
    │   ├── responsive/              # 多屏幕自适应框架 (ResponsiveQuizLayout / AdaptiveShell)
    │   ├── bridge/                  # Pigeon 通信桥接封装
    │   ├── theme/                   # 全局深浅色主题与字体缩放
    │   └── utils/                   # SHA-256 哈希工具、Fisher-Yates 选项洗牌算法
    └── features/
        ├── 1_app_monitor/           # 【模块一】受控应用管理与计时策略 (data / domain / presentation)
        ├── 2_question_bank/         # 【模块二】题库管理、JSON/ZIP 导入解析器与错题本
        ├── 3_quiz_interceptor/      # 【模块三】全屏答题闯关状态机、TTS/音频服务、5秒冷却锁组件
        └── 4_security_guard/        # 【模块四】6位 PIN 密码锁、防暴破锁定与系统权限引导向导
```

---

## 6. 核心模块代码实现规范 (Core Implementation Snippets)

### 6.1 题目多态负载模型 (`Freezed` Sealed Class)
```dart
// lib/features/2_question_bank/domain/models/question_payload.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'question_payload.freezed.dart';
part 'question_payload.g.dart';

@freezed
sealed class QuestionPayload with _$QuestionPayload {
  const factory QuestionPayload.choice({
    required List<String> options,
    @Default(true) bool shuffle,
  }) = ChoicePayload;

  const factory QuestionPayload.fillBlank({
    @Default(false) bool caseSensitive,
    String? placeholder,
  }) = FillBlankPayload;

  const factory QuestionPayload.listening({
    required String audioSource, // 'tts:ephemeral' 或 'file:001.mp3'
    required List<String> options,
    @Default(1.0) double defaultSpeed,
  }) = ListeningPayload;

  factory QuestionPayload.fromJson(Map<String, dynamic> json) =>
      _$QuestionPayloadFromJson(json);
}
```

### 6.2 跨端原生通信协议 (`pigeons/native_monitor_api.dart`)
```dart
import 'package:pigeon/pigeon.dart';

@HostApi()
abstract class NativeMonitorHostApi {
  /// 获取已安装非系统应用列表
  List<InstalledAppInfo> getInstalledApps();

  /// 同步受控黑名单包名与计时策略至原生常驻服务
  void syncMonitorPolicy(List<String> packageNames, int limitSeconds, bool isCumulative);

  /// 检查并引导开启：无障碍服务、悬浮窗、设备管理器防卸载权限
  PermissionStatusResult checkAndRequestPermissions();

  /// 答题闯关成功，通知原生层解除全屏锁定并重置当前周期计时器
  void notifyQuizPassed();
}

@FlutterApi()
abstract class NativeMonitorFlutterApi {
  /// 提前 60 秒触发顶部悬浮预警横幅
  void onWarningCountdownTick(int remainingSeconds, String currentAppName);

  /// 触发全屏答题拦截锁
  void onTriggerFullScreenLock(String triggeredPackageName, int requiredPassCount);
}
```

### 6.3 多屏幕自适应答题骨架与物理返回键拦截 (`ResponsiveQuizLayout` + `PopScope`)
```dart
// lib/features/3_quiz_interceptor/presentation/interceptor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InterceptorScreen extends StatelessWidget {
  final Widget questionHeaderAndStem;
  final Widget interactiveOptionsArea;
  final Widget? explanationPanel;

  const InterceptorScreen({
    super.key,
    required this.questionHeaderAndStem,
    required this.interactiveOptionsArea,
    this.explanationPanel,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // 强制屏蔽返回手势与物理返回键
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先完成闯关答题方可解锁屏幕！')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 桌面端 / 大平板横屏 (>= 900px)：左右双栏布局
              if (constraints.maxWidth >= 900) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 5, child: questionHeaderAndStem),
                          const SizedBox(width: 32),
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  interactiveOptionsArea,
                                  if (explanationPanel != null) explanationPanel!,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // 手机竖屏 / 小折叠屏 (< 900px)：居中限宽单栏流式布局（自适应软键盘弹起）
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      children: [
                        questionHeaderAndStem,
                        const SizedBox(height: 20),
                        interactiveOptionsArea,
                        if (explanationPanel != null) ...[
                          const SizedBox(height: 16),
                          explanationPanel!,
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
```

### 6.4 选择题选项动态洗牌与答案索引重映射算法
```dart
// lib/core/utils/option_shuffler.dart
import 'dart:math';

class ShuffledChoiceData {
  final List<String> shuffledOptions;
  final List<int> mappedCorrectIndices;

  ShuffledChoiceData({
    required this.shuffledOptions,
    required this.mappedCorrectIndices,
  });
}

ShuffledChoiceData shuffleChoiceOptions(
  List<String> originalOptions,
  List<int> originalCorrectIndices, {
  bool enableShuffle = true,
}) {
  if (!enableShuffle || originalOptions.length <= 1) {
    return ShuffledChoiceData(
      shuffledOptions: List.from(originalOptions),
      mappedCorrectIndices: List.from(originalCorrectIndices),
    );
  }

  final random = Random();
  // 创建原始索引列表 [0, 1, 2, 3] 并执行 Fisher-Yates 洗牌
  final indexMap = List<int>.generate(originalOptions.length, (i) => i);
  for (int i = indexMap.length - 1; i > 0; i--) {
    final j = random.nextInt(i + 1);
    final temp = indexMap[i];
    indexMap[i] = indexMap[j];
    indexMap[j] = temp;
  }

  final shuffledOptions = [for (final oldIdx in indexMap) originalOptions[oldIdx]];
  final mappedCorrectIndices = <int>[];

  for (int newIdx = 0; newIdx < indexMap.length; newIdx++) {
    if (originalCorrectIndices.contains(indexMap[newIdx])) {
      mappedCorrectIndices.add(newIdx);
    }
  }

  return ShuffledChoiceData(
    shuffledOptions: shuffledOptions,
    mappedCorrectIndices: mappedCorrectIndices..sort(),
  );
}
```

---

## 7. 研发里程碑规划 (Development Roadmap)

1. **Milestone 1（核心数据与题库层）：** 搭建 Flutter 工程骨架，完成 `Drift` 数据库建表、JSON/ZIP 题库导入解析器及智能混合抽题 DAO 单元测试。
2. **Milestone 2（跨端答题 UI 与语音引擎）：** 完成 `ResponsiveQuizLayout` 多端自适应界面、单选/填空/听力三大题型组件、`flutter_tts` 发音集成及答错 5 秒强制冷却状态机。
3. **Milestone 3（原生监控与霸屏拦截桥接）：** 编写 `Pigeon` 通信接口，实现 Android 端 `AccessibilityService` / `UsageStatsManager` 计时服务与 `LockInterceptorActivity` 全屏拦截，以及 iOS `Screen Time API` 扩展。
4. **Milestone 4（安全防线与多端联调）：** 实现 6 位 PIN 码加盐哈希安全锁、防暴力破解锁定、设备管理器防卸载引导向导，完成手机、平板与桌面端全流程真机测试。