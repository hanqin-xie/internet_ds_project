# Metric Definitions (v0) - Olist Growth Analytics

## 时间口径
- 日期字段：`order_purchase_timestamp`
- 日粒度：`date(order_purchase_timestamp)` 作为 dt
- 原因：购买下单时间最适合作为增长/留存/实验分桶的统一时间轴

## 订单有效性（v0）
- `is_paid`：订单在 payments 表中聚合后 `SUM(payment_value) > 0`
- `is_valid_order`（有效订单，v0）：
  - `order_status NOT IN ('canceled', 'unavailable')`
  - 且 `is_paid = 1`
- 说明：
  - canceled/unavailable 订单不计入订单数与 GMV
  - v0 简化处理：只要有支付且非取消就算有效。后续可升级为：
    - delivered 才算完成订单（用于“完成GMV/完成订单数”）
    - 对 refunds/chargeback 若数据存在则扣减

## 指标定义（v0）

### 1) 订单数 Orders
- 定义：`SUM(is_valid_order)`
- 粒度：dt（日）

### 2) GMV
- 定义：`SUM(paid_value)`（仅有效订单）
- 口径来源：payments 表聚合 `SUM(payment_value)`
- 备注：与 items_value 可能不一致（运费/优惠/分期等），Day1 先固定用 payments 口径；后续可对齐并解释差异

### 3) 活跃买家 Active Buyers
- 定义：有效订单的去重买家数
- 字段：`customer_unique_id`
- 公式：`COUNT(DISTINCT customer_unique_id)`（仅有效订单）
- 说明：customer_id 可能随地址变化，unique_id 更接近“用户”

### 4) 客单价 AOV
- 定义：`GMV / Orders`
- 公式：`SUM(paid_value) / SUM(is_valid_order)`（仅有效订单）

## 数据质量与校验清单（Day1）
- orders 表行数 vs v_order_fact 行数应一致（LEFT JOIN 聚合不应导致重复）
- 抽样检查同一 order_id 在 payments/items 中的聚合是否正确
- 查看 `paid_value` 与 `items_value` 差异最大的订单，确认合理性
