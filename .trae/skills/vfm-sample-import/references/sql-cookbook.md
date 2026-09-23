# SQL 模板与字段速查

## 1. 目标列（20 列，顺序即脚本 `COLS` 顺序）

```
sample_code, store_code, store_name,
check_code, check_name, check_image, check_desc,
district_code, district_name, area_code, area_name,
region_code, region_name,
review_result, source_app, scene, scene_category, scene_flag,
extra_info, create_time
```

`vfm_debug_sample` 除 `area_*` 外基本 `NOT NULL` 且无默认值 → SELECT 必须给全。

---

## 2. 生产取数 SQL（warnings + warning_images，改 type 即换检查项）

```sql
SELECT
  CONCAT('HY', w.id)                                  AS sample_code,
  w.store_code,
  w.store_name,
  CAST(w.type AS CHAR)                                AS check_code,
  w.type_name                                         AS check_name,
  LEFT(IFNULL(NULLIF(wi.url, ''), w.image_url), 1000) AS check_image,
  LEFT(IFNULL(w.content, ''), 255)                    AS check_desc,
  ''     AS district_code,
  ''     AS district_name,
  ''     AS area_code,
  ''     AS area_name,
  ''     AS region_code,
  ''     AS region_name,
  0      AS review_result,
  'ai_inspection' AS source_app,
  'AI巡店'        AS scene,
  'default'       AS scene_category,
  'default'       AS scene_flag,
  JSON_OBJECT('warningId', w.id, 'messageId', w.message_id,
              'startTime', w.start_time, 'endTime', w.end_time,
              'duration', w.duration) AS extra_info,
  w.create_time
FROM warnings w
LEFT JOIN warning_images wi
  ON wi.id = (
    SELECT wi2.id FROM warning_images wi2
    WHERE wi2.warning_id = w.id
      AND IFNULL(wi2.file_type, 0) = 0      -- 0/NULL = 图片
    ORDER BY wi2.id ASC LIMIT 1             -- 一 warning 只取一张图
  )
WHERE w.type = 20                           -- ← 换检查项改这里
ORDER BY w.id DESC
LIMIT 200;                                  -- ← 换条数改这里
```

### 变体：需要片区 / 大区时追加

```sql
  ... 
FROM warnings w
LEFT JOIN warning_images wi ON wi.id = ( ... )
LEFT JOIN store_structure ss ON ss.store_code = w.store_code
-- 把 SELECT 里的 '' 替换为：
--   district_code ← ss.piece_code         district_name ← ss.piece_name
--   region_code   ← ss.distribution_code  region_name   ← ss.distribution_name
--   area_*        ← 无来源，仍填 ''
```

---

## 3. 生成脚本

`ai-store-api/src/ai-recognition/scripts/gen-sample-insert.js`

```bash
node scripts/gen-sample-insert.js <input.txt> [output.sql]
# 默认 ../data.txt → ../type-import.sql
```

行为：

- 跳过文件开头所有「不含 `\t`」的行（竖排列名/空行），从第一行 TSV 开始；
- 固定 20 列取值，`'` 与 `\` 转义；
- 缺列补默认：`district/area/region → ''`、`review_result → 0`、`source_app/scene/... → 默认`、`extra_info → {"warningId": <id>}`、`create_time → NULL`（走表默认）；
- 输出 `INSERT ... VALUES (...),(...)` + `ON DUPLICATE KEY UPDATE`（按 `sample_code`），幂等。

---

## 4. 执行与校验

```bash
# 目标库执行
mysql -h <host> -P 3306 -u <user> -p <database> < type20-import.sql
```

```sql
-- mysql 交互终端
source /abs/path/to/type20-import.sql;

-- 校验
SELECT COUNT(*) total,
       SUM(check_code = '20') typed,
       SUM(check_image = '') empty_image
FROM vfm_debug_sample
WHERE sample_code LIKE 'HY%' AND deleted = 0;
```

---

## 5. 换数据源的扩展位

| 换成 | 要改的地方 |
| --- | --- |
| 别的 `check_code` | SELECT 的 `WHERE w.type = XX`，文件名 `typeXX-import.sql` |
| 需要机构信息 | 加 `LEFT JOIN store_structure`（见变体） |
| 别的源表 | 只重写 SELECT 的 20 列来源，Step 3~5 不变 |
| 别的目标表 | 改脚本里的 `COLS` / `DEF` 与 `INSERT INTO <table>` |
