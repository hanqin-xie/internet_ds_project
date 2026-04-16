# Olist Growth Analytics - One Pager

## 项目一句话

基于 Olist SQLite 电商数据，我独立完成了一套从指标口径、漏斗、cohort、复购驱动分析，到实验设计、历史 A/B 演练和可视化展示的增长分析项目。

## 业务问题

- 交易链路的主要损耗在哪里
- 物流体验是否会伤害评价与后续复购
- 如果要做履约 SLA 优化实验，应该怎么定义指标、样本量和上线标准

## 我做了什么

1. 从原始订单、支付、评论、商品和客户表搭建统一指标口径。
2. 分析漏斗和物流体验，定位“晚于承诺时间”是更强的差评驱动因素。
3. 构建首单 cohort，验证平台属于低频复购场景，`30d repeat` 很低。
4. 设计 `First-order SLA Upgrade` 实验，并用历史数据做分层随机和 uplift 演练。
5. 做了一个 Streamlit dashboard，把趋势、cohort、SLA 诊断和实验结论集中展示。

## 关键发现

- 交易前段并不是核心瓶颈，支付与发货转化都很高。
- 一旦晚到超过 `4` 天，差评风险急剧上升。
- Olist 的 `30d repeat` 约 `1.6%`，更适合“两阶段实验”而不是只盯长期指标。
- 历史 A/B 模拟里，SLA 升级让 `30d repeat`、`late share`、`bad review share` 都改善，但 `freight / order` 明显上升。

## 实验判断

默认模拟结论不是“直接上线”，而是：

`继续跑 / 小范围放量，同时严密监控物流成本护栏。`

原因：

- 主指标方向正确：`30d repeat +0.33pp`
- 机制指标方向正确：`late share -1.41pp`
- 体验指标方向正确：`bad review share -0.89pp`
- 但成本 proxy 恶化：`freight / order +1.03`
