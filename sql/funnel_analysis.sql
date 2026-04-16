-- sql/funnel_analysis.sql
-- 目标：建立交易漏斗视图 + 假设分析所需的订单级字段

DROP VIEW IF EXISTS v_funnel_order;

CREATE VIEW v_funnel_order AS
WITH
pay AS (
  SELECT
    order_id,
    SUM(payment_value) AS paid_value
  FROM order_payments
  GROUP BY order_id
),

review_dedup AS (
  SELECT
    order_id,
    review_id,
    review_score,
    review_creation_date,
    review_answer_timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY order_id
      ORDER BY review_answer_timestamp DESC, review_creation_date DESC, review_id DESC
    ) AS rn
  FROM order_reviews
),

review_final AS (
  SELECT
    order_id,
    review_id,
    review_score,
    review_creation_date,
    review_answer_timestamp
  FROM review_dedup
  WHERE rn = 1
)

SELECT
  o.order_id,
  o.customer_id,
  c.customer_unique_id,
  o.order_status,
  o.order_purchase_timestamp,
  o.order_approved_timestamp,
  o.order_delivered_carrier_date,
  o.order_delivered_customer_date,
  o.order_estimated_delivery_date,
  COALESCE(p.paid_value, 0) AS paid_value,
  rf.review_id,
  rf.review_score,
  rf.review_creation_date,
  rf.review_answer_timestamp,

  CASE WHEN o.order_purchase_timestamp IS NOT NULL THEN 1 ELSE 0 END AS step_purchase,
  CASE
    WHEN COALESCE(p.paid_value, 0) > 0
         OR o.order_approved_timestamp IS NOT NULL
    THEN 1 ELSE 0
  END AS step_payment,
  CASE WHEN o.order_delivered_carrier_date IS NOT NULL THEN 1 ELSE 0 END AS step_shipped,
  CASE WHEN o.order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END AS step_delivered,
  CASE WHEN rf.review_id IS NOT NULL THEN 1 ELSE 0 END AS step_reviewed,

  CASE
    WHEN o.order_purchase_timestamp IS NOT NULL
         AND (COALESCE(p.paid_value, 0) > 0 OR o.order_approved_timestamp IS NOT NULL)
    THEN julianday(COALESCE(o.order_approved_timestamp, o.order_purchase_timestamp))
         - julianday(o.order_purchase_timestamp)
    ELSE NULL
  END AS purchase_to_payment_days,

  CASE
    WHEN o.order_approved_timestamp IS NOT NULL
         AND o.order_delivered_carrier_date IS NOT NULL
    THEN julianday(o.order_delivered_carrier_date) - julianday(o.order_approved_timestamp)
    ELSE NULL
  END AS payment_to_ship_days,

  CASE
    WHEN o.order_delivered_carrier_date IS NOT NULL
         AND o.order_delivered_customer_date IS NOT NULL
    THEN julianday(o.order_delivered_customer_date) - julianday(o.order_delivered_carrier_date)
    ELSE NULL
  END AS ship_to_delivered_days,

  CASE
    WHEN o.order_purchase_timestamp IS NOT NULL
         AND o.order_delivered_customer_date IS NOT NULL
    THEN julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)
    ELSE NULL
  END AS purchase_to_delivered_days,

  CASE
    WHEN o.order_estimated_delivery_date IS NOT NULL
         AND o.order_delivered_customer_date IS NOT NULL
    THEN julianday(o.order_delivered_customer_date) - julianday(o.order_estimated_delivery_date)
    ELSE NULL
  END AS delivery_delay_vs_estimate_days,

  CASE
    WHEN rf.review_score IS NOT NULL AND rf.review_score <= 2 THEN 1 ELSE 0
  END AS is_bad_review
FROM orders o
LEFT JOIN pay p
  ON o.order_id = p.order_id
LEFT JOIN customers c
  ON o.customer_id = c.customer_id
LEFT JOIN review_final rf
  ON o.order_id = rf.order_id
;

DROP VIEW IF EXISTS v_funnel_overall;

CREATE VIEW v_funnel_overall AS
SELECT '下单' AS stage, SUM(step_purchase) AS orders FROM v_funnel_order
UNION ALL
SELECT '支付' AS stage, SUM(step_payment) AS orders FROM v_funnel_order
UNION ALL
SELECT '发货' AS stage, SUM(step_shipped) AS orders FROM v_funnel_order
UNION ALL
SELECT '签收' AS stage, SUM(step_delivered) AS orders FROM v_funnel_order
UNION ALL
SELECT '评价' AS stage, SUM(step_reviewed) AS orders FROM v_funnel_order
;
