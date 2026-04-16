-- sql/cohort.sql
-- 目标：定义首单 cohort，并计算按月复购/留存
-- 依赖：sql/metrics_v0.sql 中的 v_order_fact

DROP VIEW IF EXISTS v_user_order_months;

CREATE VIEW v_user_order_months AS
SELECT
  customer_unique_id,
  date(strftime('%Y-%m-01', order_purchase_timestamp)) AS order_month,
  COUNT(DISTINCT order_id) AS orders
FROM v_order_fact
WHERE is_valid_order = 1
  AND customer_unique_id IS NOT NULL
  AND order_purchase_timestamp IS NOT NULL
GROUP BY 1, 2
;

DROP VIEW IF EXISTS v_user_cohort;

CREATE VIEW v_user_cohort AS
SELECT
  customer_unique_id,
  MIN(order_month) AS cohort_month
FROM v_user_order_months
GROUP BY 1
;

DROP VIEW IF EXISTS v_cohort_retention;

CREATE VIEW v_cohort_retention AS
WITH cohort_size AS (
  SELECT
    cohort_month,
    COUNT(*) AS cohort_users
  FROM v_user_cohort
  GROUP BY 1
),
activity AS (
  SELECT
    c.cohort_month,
    u.order_month,
    (
      CAST(strftime('%Y', u.order_month) AS INTEGER) * 12
      + CAST(strftime('%m', u.order_month) AS INTEGER)
    ) - (
      CAST(strftime('%Y', c.cohort_month) AS INTEGER) * 12
      + CAST(strftime('%m', c.cohort_month) AS INTEGER)
    ) AS month_number,
    COUNT(DISTINCT u.customer_unique_id) AS active_users
  FROM v_user_cohort c
  JOIN v_user_order_months u
    ON c.customer_unique_id = u.customer_unique_id
   AND u.order_month >= c.cohort_month
  GROUP BY 1, 2, 3
)
SELECT
  a.cohort_month,
  a.order_month,
  a.month_number,
  s.cohort_users,
  a.active_users,
  1.0 * a.active_users / NULLIF(s.cohort_users, 0) AS retention_rate
FROM activity a
JOIN cohort_size s
  ON a.cohort_month = s.cohort_month
ORDER BY 1, 3
;

DROP VIEW IF EXISTS v_cohort_repeat_summary;

CREATE VIEW v_cohort_repeat_summary AS
WITH base AS (
  SELECT
    cohort_month,
    MAX(CASE WHEN month_number = 0 THEN cohort_users END) AS cohort_users,
    MAX(CASE WHEN month_number = 1 THEN active_users END) AS m1_repeat_users,
    MAX(CASE WHEN month_number = 3 THEN active_users END) AS m3_repeat_users
  FROM v_cohort_retention
  GROUP BY 1
)
SELECT
  cohort_month,
  cohort_users,
  COALESCE(m1_repeat_users, 0) AS m1_repeat_users,
  COALESCE(m3_repeat_users, 0) AS m3_repeat_users,
  1.0 * COALESCE(m1_repeat_users, 0) / NULLIF(cohort_users, 0) AS m1_repeat_rate,
  1.0 * COALESCE(m3_repeat_users, 0) / NULLIF(cohort_users, 0) AS m3_repeat_rate
FROM base
ORDER BY cohort_month
;
