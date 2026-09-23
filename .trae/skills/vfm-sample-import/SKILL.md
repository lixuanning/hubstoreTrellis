---
name: vfm-sample-import
description: "把生产业务表数据导入 AI 巡店样本表 vfm_debug_sample 的标准流程：确认 check_code 与字段映射 → 生成只读的生产 SELECT（慧云预警 warnings + warning_images 等）→ 用户导出 TSV → 用 scripts/gen-sample-insert.js 生成按 sample_code 幂等的 INSERT SQL → 在目标库执行 → 校验条数。当用户说「给 vfm_debug_sample 造/导入数据」「把 type/检查项 XX 导进样本表」「导入 200 条 type 20 样本」「从 warnings 表导数据到样本表」时使用。"
---

# VFM 样本数据导入

把业务库数据 → `vfm_debug_sample`（AI 巡店样本表）的可复现流程。**生产库只读，写入只打目标库。**

完整过程记录（含案例）：`ai-store-api/docs/VFM_SAMPLE_DATA_IMPORT.md`。

## 触发

- 「给 vfm_debug_sample 造点数据 / 导入数据」
- 「把 type 20 / 检查项 122 的数据导进样本表」
- 「从 warnings 导 200 条样本」

## 前置（必做，不要跳过）

1. 读目标列定义：`ai-store-api/src/ai-recognition/db.txt` 里的 `vfm_debug_sample` 建表语句；
2. 读源表实体：`ai-store-api/src/warning/warnings/warning.entity.ts`、`warning-image.entity.ts`（换源表则读对应 entity）；
3. 读 `references/sql-cookbook.md` 拿 SQL 模板与字段映射；
4. 若要机构（片区/大区）字段，另读 `src/store-structure/store-structure.entity.ts`。

## 字段映射（warnings → vfm_debug_sample）

| 目标列 | 来源 |
| --- | --- |
| `sample_code` | `CONCAT('HY', warnings.id)` —— **禁用 `message_id`**（uuid 超 `varchar(30)`） |
| `store_code` / `store_name` | `warnings.store_code` / `store_name` |
| `check_code` / `check_name` | `warnings.type` / `type_name`（名称以 `check_items` 为准） |
| `check_image` | `warning_images.url`（`IFNULL(file_type,0)=0`），兜底 `warnings.image_url` |
| `check_desc` | `warnings.content`（`LEFT(...,255)`） |
| `district_*` / `area_*` / `region_*` | 默认 `''`；需片区/大区时 `LEFT JOIN store_structure`（区域无来源） |
| `review_result` | `0` |
| `source_app` / `scene` / `scene_category` / `scene_flag` | `'ai_inspection'` / `'AI巡店'` / `'default'` / `'default'` |
| `extra_info` | `JSON_OBJECT('warningId',...,'messageId',...,'startTime',...,'endTime',...,'duration',...)` |

`check_code → check_name` 权威来源：`check_items` 种子数据（`src/ai-recognition/db.txt`）。如 `20 空货架捕捉`、`117 戴首饰`、`122 开切未佩戴手套`。

## 执行流程

### Step 1 定位检查项

问清 / 确认 `check_code`（如 `20`）与期望条数。`check_name` 从 `check_items` 取。

### Step 2 产出生产取数 SQL（只读）

用 `references/sql-cookbook.md` 的模板，把 `WHERE w.type = 20` 的目标类型与 `LIMIT` 换掉即可。
**SELECT 列顺序必须与脚本 `COLS` 一致**（20 列，固定顺序）。

交付给用户，说明：在生产库执行、导出为 TSV（`data.txt`）。文件开头的竖排列名不用手动删。

### Step 3 生成 INSERT SQL

```bash
cd ai-store-api/src/ai-recognition
node scripts/gen-sample-insert.js data.txt type<XX>-import.sql
```

脚本自动跳过竖排列名、补默认值、生成 `ON DUPLICATE KEY UPDATE`（按 `sample_code`，可重复执行）。

### Step 4 交付执行方式

```bash
mysql -h <host> -P 3306 -u <user> -p <database> < type<XX>-import.sql
```
已在 `mysql` 交互终端：`source /abs/path/type<XX>-import.sql;`
或客户端（Navicat/DBeaver）打开该 `.sql` 执行。

### Step 5 给校验 SQL

```sql
SELECT COUNT(*) total, SUM(check_code = '<XX>') typed, SUM(check_image = '') empty_image
FROM vfm_debug_sample WHERE sample_code LIKE 'HY%' AND deleted = 0;
```

## 注意事项（踩过的坑）

1. `sample_code` 是 `varchar(30)` 唯一键 —— 用 `HY + warnings.id`，别用 uuid。
2. 一 warning 多图 —— 必须子查询只取一张，否则 JOIN 出多行、样本重复。
3. `vfm_debug_sample` 几乎每列 `NOT NULL` 无默认 —— 每列都要给值，机构字段至少 `''`。
4. `warning_images.file_type`：`1=视频`，`0/NULL=图片`，取图要 `IFNULL(file_type,0)=0`。
5. 导出的 TSV 末行可能被截断（列数不足）—— 脚本按默认值补齐，日志里 `truncated=N` 需人工确认。
6. **生产环境只跑 SELECT**，INSERT 只在目标库执行。
7. 换源表（非 warnings）时，只需重做 Step 2 的 SELECT 与映射表，Step 3~5 不变。
