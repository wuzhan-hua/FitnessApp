# 离线食物模板导入脚本说明

脚本文件：`tool/import_food_images.dart`

仓库内已附一个可直接导入或继续补充的离线营养模板：

- `tool/sample_food_image_manifest.json`

## 目标

将一份已经整理好的离线食物营养模板批量导入 `food_catalog_items`：

- 按食物名称精确去重
- Supabase 已有同名食物则跳过
- 自动匹配现有分类
- 分类不存在时自动新增
- 自动生成 `food_code`
- 输出失败清单，避免静默失败

## 运行方式

```bash
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...
FOOD_IMAGE_IMPORT_INPUT=tool/sample_food_image_manifest.json
dart run tool/import_food_images.dart
```

可选参数：

```bash
FOOD_IMAGE_IMPORT_DRY_RUN=true
FOOD_IMAGE_IMPORT_BATCH_SIZE=50
FOOD_IMAGE_IMPORT_SOURCE=ai-estimated-import
FOOD_IMAGE_IMPORT_FAILURE_REPORT=tool/food_image_import_failures.json
```

## 环境变量

- `SUPABASE_URL`：Supabase 项目地址
- `SUPABASE_SERVICE_ROLE_KEY`：Service Role Key
- `FOOD_IMAGE_IMPORT_INPUT`：离线营养模板 JSON 路径
- `FOOD_IMAGE_IMPORT_BATCH_SIZE`：批量写入条数，默认 `50`
- `FOOD_IMAGE_IMPORT_SOURCE`：写入 `source` 字段，默认 `ai-estimated-import`
- `FOOD_IMAGE_IMPORT_FAILURE_REPORT`：失败清单输出路径，默认 `tool/food_image_import_failures.json`
- `FOOD_IMAGE_IMPORT_DRY_RUN`：`true/false`，为 `true` 时不写库

## 模板格式

输入必须是 JSON 数组，每条食物都独立一项，不再包含 `image_path`。

```json
[
  {
    "food_name": "拿铁",
    "category_name": "奶类及制品",
    "portion_text": "1.00大杯(Grande)",
    "aliases": ["拿铁咖啡"],
    "remark": "按截图热量估算",
    "edible": 100,
    "water": 83.5,
    "energy_kcal": 203,
    "energy_kj": 849,
    "protein": 8.6,
    "fat": 8.2,
    "carb": 23.8,
    "dietary_fiber": 0,
    "cholesterol": 18,
    "ash": 1.2,
    "vitamin_a": 36,
    "carotene": 0,
    "retinol": 33,
    "thiamin": 0.04,
    "riboflavin": 0.33,
    "niacin": 0.6,
    "vitamin_c": 0,
    "vitamin_e_total": 0.2,
    "vitamin_e1": 0,
    "vitamin_e2": 0,
    "vitamin_e3": 0.2,
    "calcium": 285,
    "phosphorus": 210,
    "potassium": 360,
    "sodium": 92,
    "magnesium": 28,
    "iron": 0.3,
    "zinc": 0.9,
    "selenium": 3.2,
    "copper": 0.03,
    "manganese": 0.02
  }
]
```

## 最低要求

每条记录至少需要：

- `food_name`
- `category_name`
- `portion_text`
- `energy_kcal`
- `protein`
- `fat`
- `carb`

其余营养字段若缺失会按 `0` 或默认值处理，但建议模板中补齐完整字段，方便后续管理页直接维护。

## 去重与分类规则

- 去重只按 `food_name` 精确匹配，命中即跳过，不更新旧数据
- 分类名优先匹配现有 `food_categories`
- 若分类不存在，脚本自动新增并默认排在现有分类末尾

## 备注与来源

- `remark` 会写入你在模板中的备注
- 脚本还会自动补充：
  - 导入来源
  - 营养口径：按截图热量估算
  - 份量说明
  - 别名（如果有）

## 失败清单

脚本会把未导入成功的条目输出到：

- 默认：`tool/food_image_import_failures.json`

失败不会静默吞掉，便于后续补录或手动修正。
