# 健身记录 App - AI 工作规范（AGENTS.md）

## 1. 项目背景

本项目是一个面向“有训练基础用户”的健身记录 App 原型，支持多端：

* Flutter（iOS / Android）
* H5（Web）

后端使用 Supabase（PostgreSQL + Auth + Storage）

核心定位：
轻量、高效、专业的训练记录工具（非跟练类应用）

---


## 3. AI 工作规则（强约束）

* 所有输出必须使用中文
* 必须遵循最小改动原则
* 不允许擅自重构代码
* 不允许猜测需求，必须先确认
* 所有代码必须可运行
* 必要时可使用已有 skill

---

## 4. 项目结构规范

lib/
  ├── main.dart
  ├── pages/          # 页面（UI）
  ├── widgets/        # 公共组件
  ├── services/       # Supabase 调用
  ├── models/         # 数据模型
  ├── state/          # 状态管理（如 Riverpod）
  ├── utils/          # 工具类
  └── constants/      # 常量

web/（H5）
supabase/
  ├── migrations/
  ├── functions/

---

## 5. 架构约束（非常重要）

* 页面（pages）禁止直接访问 Supabase
* 所有数据请求必须走 services 层
* services 只负责数据，不写 UI 逻辑
* state 层负责状态管理（训练中状态等）

---

## 6. 数据模型规范

每个模型必须：
- 有 fromJson / toJson
- 不允许在 UI 层解析 JSON

示例：

```dart
class WorkoutRecord {
  final String id;
  final String userId;
  final String exerciseName;
  final int sets;
  final int reps;
  final double weight;
  final DateTime createdAt;

  WorkoutRecord({
    required this.id,
    required this.userId,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.createdAt,
  });
}

---

## 7. 网络与错误处理

* 所有请求必须使用 try-catch
* 必须返回明确错误信息
* 不允许 silent fail（静默失败）
* 所有错误必须统一封装（utils 或 service 层）
* 网络请求失败必须提供用户可见提示
* Supabase 异常必须解析 error message

---

## 8. UI / 交互规范（重点）

整体设计原则：

极简 + 高效 + 工具型（类似专业训练记录工具）

必须遵守：

* 每个页面必须有 loading 状态
* 每个操作必须有反馈（成功/失败）
* 所有请求必须异步处理
* 不允许阻塞 UI

组件规范：

* 单个 Widget 不超过 200 行
* 可复用组件必须拆分到 widgets/
* 输入表单必须支持校验


## 10. Supabase 规范

数据库必须包含：

* users
* workout_records

所有表必须包含：

* id（uuid）
* user_id
* created_at

约束：

* 不允许随意修改表结构
* 必须实现用户数据隔离（user_id）

---

## 11. 健身业务规则（强约束）

* 每条训练记录必须属于一个用户
* 数据不可覆盖（只能新增）
* 历史记录必须可追溯
* 每条记录必须包含：

  * 动作名称
  * 组数
  * 次数
  * 重量

---

## 12. 质量约束

* 禁止未使用变量
* 禁止使用 print 调试（必须使用 logger）
* 必须通过编译
* 不允许重复代码

---

## 13. 禁止操作

* 不允许修改数据库结构（除非明确说明）
* 不允许删除已有字段
* 不允许新增未说明依赖
* 不允许修改已有接口返回结构

---

## 14. AI 执行流程（必须遵守）

当用户提出需求时：

1. 分析需求
2. 输出功能拆解（页面 / 数据 / 交互）
3. 输出实现方案
4. 等待确认
5. 编写代码
6. 自检（逻辑 + 编译）
7. 输出变更说明

禁止直接写代码

---

## 15. 任务模板（重要）

当我说：

开发 XXX 功能

你必须：

1. 拆解：

   * 页面
   * 数据结构
   * 交互逻辑
2. 输出方案
3. 等待确认
4. 再开始写代码
