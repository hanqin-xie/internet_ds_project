# A/B Simulation Results - Fulfillment SLA Upgrade

## 模拟设置

- 样本：`83,596` 个首个有效订单用户，且保留至少 `60d` 观察窗口
- 随机化：按 `destination_region x first_paid_value_bucket` 分层后做 `50 / 50` 随机
- 基线平衡检查：
  - `first_paid_value`：control 与 treatment 几乎一致，差值约 `+0.01`，`p = 0.994`
  - `late_share`：分组前差值约 `-0.14pp`，`p = 0.442`

默认 uplift 场景：

- treatment 对正向晚到订单减少 `1.5` 天 `delay`
- 差评率根据新的 `delay bucket` 用历史经验率重采样
- `30d repeat` 在新体验基础上额外增加 `+0.35pp`
- `freight_value / order` 增加 `0.8`，作为物流成本 proxy

## 结果

| Metric | Control | Treatment | Diff | 95% CI | p-value |
| --- | ---: | ---: | ---: | ---: | ---: |
| `30d repeat` | `1.61%` | `1.95%` | `+0.33pp` | `[+0.15pp, +0.51pp]` | `0.00030` |
| `late share` | `8.08%` | `6.67%` | `-1.41pp` | `[-1.76pp, -1.06pp]` | `<0.001` |
| `4d+ late share` | `5.15%` | `4.41%` | `-0.74pp` | `[-1.03pp, -0.45pp]` | `<0.001` |
| `bad review share` | `14.38%` | `13.48%` | `-0.89pp` | `[-1.36pp, -0.43pp]` | `<0.001` |
| `freight / order` | `22.50` | `23.53` | `+1.03` | `[+0.74, +1.32]` | `<0.001` |

## 结论

结论模板落地成这次默认场景后，我的建议是：`不直接上线，继续跑 / 小范围放量`。

原因很直接：

- 主指标 `30d repeat` 有正向且显著的提升
- 机制指标 `late share`、`4d+ late share`、`bad review share` 方向都对
- 但护栏里的 `freight / order` 明显恶化，说明更快 SLA 很可能在成本侧有真实代价

如果把这次结果放进真实决策，我会更偏向下面这句：

`可以继续跑，但不建议全量上线；需要先确认物流成本 uplift 是否能被复购和差评改善覆盖。`

## 需要什么监控

- `30d repeat`
- `late share`
- `4d+ late share`
- `bad review share`
- `freight_value / order` 或真实 `物流成本 / 单`
- 分层看板：`region`、`basket_value_bucket`
- `SRM` 与流量分配稳定性

## 风险与说明

- 这不是严格因果识别，只是基于历史样本做的一次可解释“演练”
- `freight_value / order` 是数据集中可用的成本 proxy，不等于真实履约总成本
- `bad review` 和 `repeat_30d` 的 treatment 结果带有规则注入与经验率重采样成分，适合做实验方案 sanity check，不适合替代真实线上实验

## 对应文件

- [notebooks/06_ab_simulation.ipynb](/Users/hanqin/internet_ds_project/notebooks/06_ab_simulation.ipynb)
- [reports/ab_results.md](/Users/hanqin/internet_ds_project/reports/ab_results.md)
