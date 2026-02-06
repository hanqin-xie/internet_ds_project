-- sql/metrics_v0.sql
-- 目标：建立 order_fact + 基础指标（日粒度）
-- 口径假设见 reports/metric_definitions.md

-- ================
-- 1) 订单粒度事实表：order_fact
-- ================

DROP VIEW IF EXISTS v_order_fact;

CREATE VIEW v_order_fact AS
WITH
-- 1.1 payments 聚合到订单粒度
pay AS (
  SELECT
    order_id,
    SUM(payment_value) AS paid_value
  FROM olist_order_payments_dataset
  GROUP BY order_id
),

-- 1.2 items 聚合到订单粒度（商品金额 + 运费）
itm AS (
  SELECT
    order_id,
    SUM(price) AS items_price,
    SUM(freight_value) AS freight_value,
    SUM(price + freight_value) AS items_value,
    COUNT(*) AS item_cnt
  FROM olist_order_items_dataset
  GROUP BY order_id
),

-- 1.3 customer 映射（customer_id -> customer_unique_id）
cust AS (
  SELECT
    customer_id,
    customer_unique_id
  FROM olist_customers_dataset
),

-- 1.4 orders 主表（日期统一用 purchase_timestamp）
ord AS (
  SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp
  FROM olist_orders_dataset o
)

SELECT
  ord.order_id,
  ord.customer_id,
  cust.customer_unique_id,
  ord.order_status,
  ord.order_purchase_timestamp,

  COALESCE(pay.paid_value, 0) AS paid_value,
  COALESCE(itm.items_value, 0) AS items_value,
  COALESCE(itm.items_price, 0) AS items_price,
  COALESCE(itm.freight_value, 0) AS freight_value,
  COALESCE(itm.item_cnt, 0) AS item_cnt,

  CASE WHEN COALESCE(pay.paid_value, 0) > 0 THEN 1 ELSE 0 END AS is_paid,

  -- v0 有效订单：非取消 + 有支付
  CASE
    WHEN ord.order_status NOT IN ('canceled', 'unavailable')
         AND COALESCE(pay.paid_value, 0) > 0
    THEN 1 ELSE 0
  END AS is_valid_order
FROM ord
LEFT JOIN pay  ON ord.order_id = pay.order_id
LEFT JOIN itm  ON ord.order_id = itm.order_id
LEFT JOIN cust ON ord.customer_id = cust.customer_id
;

-- ================
-- 2) 基础指标（日粒度）
-- 订单数、GMV、活跃买家、客单价
-- ================

DROP VIEW IF EXISTS v_metrics_daily_v0;

CREATE VIEW v_metrics_daily_v0 AS
WITH base AS (
  SELECT
    date(order_purchase_timestamp) AS dt,
    *
  FROM v_order_fact
  WHERE order_purchase_timestamp IS NOT NULL
)
SELECT
  dt,

  -- 订单数：有效订单数
  SUM(is_valid_order) AS orders,

  -- GMV：有效订单 paid_value 求和（v0 选 payments 口径）
  SUM(CASE WHEN is_valid_order = 1 THEN paid_value ELSE 0 END) AS gmv,

  -- 活跃买家：有效订单的去重买家数（unique_id）
  COUNT(DISTINCT CASE WHEN is_valid_order = 1 THEN customer_unique_id END) AS active_buyers,

  -- 客单价：GMV / 订单数
  CASE WHEN SUM(is_valid_order) > 0
       THEN 1.0 * SUM(CASE WHEN is_valid_order = 1 THEN paid_value ELSE 0 END) / SUM(is_valid_order)
       ELSE NULL
  END AS aov
FROM base
GROUP BY dt
;

-- ================
-- 3) 口径校验（建议在DB里手动跑这些查询）
-- ================
-- 3.1 订单数 vs fact 行数
-- SELECT COUNT(*) FROM olist_orders_dataset;
-- SELECT COUNT(*) FROM v_order_fact;

-- 3.2 有支付订单占比
-- SELECT AVG(is_paid) FROM v_order_fact;

-- 3.3 取消订单占比
-- SELECT order_status, COUNT(*) cnt
-- FROM v_order_fact
-- GROUP BY 1
-- ORDER BY cnt DESC;

-- 3.4 payments 与 items 口径差异（抽样看）
-- SELECT order_id, paid_value, items_value, (paid_value - items_value) diff
-- FROM v_order_fact
-- WHERE is_valid_order = 1
-- ORDER BY ABS(diff) DESC
-- LIMIT 50;
