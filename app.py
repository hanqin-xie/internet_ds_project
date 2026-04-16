from pathlib import Path

import pandas as pd
import streamlit as st


ROOT = Path(__file__).resolve().parent
FIG_DIR = ROOT / "reports" / "figures"

SUMMARY_METRICS = {
    "gmv_million": 15.9,
    "orders": 99441,
    "avg_daily_orders": 157,
    "repeat_30d": 0.0162,
    "late_share": 0.0801,
}

CORE_FINDINGS = [
    "Late delivery is a stronger driver of bad reviews than total delivery duration.",
    "Olist behaves like a low-frequency marketplace: 30d repeat is only about 1.6%.",
    "Historical A/B simulation suggests SLA upgrades help CX and repeat, but cost guardrails matter.",
]

AB_RESULTS = pd.DataFrame(
    [
        {"Metric": "30d repeat", "Control": "1.61%", "Treatment": "1.95%", "Diff": "+0.33pp", "Decision": "Positive"},
        {"Metric": "Late share", "Control": "8.08%", "Treatment": "6.67%", "Diff": "-1.41pp", "Decision": "Positive"},
        {"Metric": "Bad review share", "Control": "14.38%", "Treatment": "13.48%", "Diff": "-0.89pp", "Decision": "Positive"},
        {"Metric": "Freight / order", "Control": "22.50", "Treatment": "23.53", "Diff": "+1.03", "Decision": "Guardrail hit"},
    ]
)

def image_or_warning(filename: str, caption: str):
    path = FIG_DIR / filename
    if path.exists():
        st.image(str(path), caption=caption, use_container_width=True)
    else:
        st.warning(f"Missing figure: {path}")


st.set_page_config(page_title="Olist Growth Dashboard", page_icon=":bar_chart:", layout="wide")

st.title("Olist Growth & Fulfillment Story")
st.write(
    "一个面向作品集展示的增长分析 dashboard：把 GMV 趋势、cohort 复购、物流 SLA 与差评/复购关系，"
    "以及历史 A/B 演练结论放在同一页里，方便快速讲清楚业务问题、分析方法和上线建议。"
)

st.sidebar.header("Filters")
region = st.sidebar.selectbox("Destination region", ["All"], index=0)
min_cohort_users = st.sidebar.slider("Minimum cohort size", min_value=100, max_value=4000, value=1000, step=100)
st.sidebar.caption("当前展示版使用项目已产出的核心结果，适合作品集和面试演示。")
st.sidebar.caption("如需完全实时筛选版，可以在此基础上再做轻量 SQL 优化。")

metric_cols = st.columns(4)
with metric_cols[0]:
    st.metric("Total GMV", f"R$ {SUMMARY_METRICS['gmv_million']:.1f}M", f"{SUMMARY_METRICS['orders']:,} valid orders")
with metric_cols[1]:
    st.metric("Avg Daily Orders", f"{SUMMARY_METRICS['avg_daily_orders']:,}", f"Region: {region}")
with metric_cols[2]:
    st.metric("30d Repeat", f"{SUMMARY_METRICS['repeat_30d'] * 100:.2f}%", "First-order users only")
with metric_cols[3]:
    st.metric("Late Share", f"{SUMMARY_METRICS['late_share'] * 100:.2f}%", "Delivered after estimated date")

left, right = st.columns([1.1, 0.9])

with left:
    st.subheader("GMV Trend")
    image_or_warning("funnel_overall.png", "Project funnel figure")
    st.caption("补充说明：项目里最终更偏重履约体验与复购，因此这里用总体业务图作为首页引导位。")

with right:
    st.subheader("Core Findings")
    for finding in CORE_FINDINGS:
        st.write(f"- {finding}")
    st.caption("Metric source: SQLite views + notebook outputs")
    st.caption("Audience: portfolio / interview walkthrough")
    st.caption("Decision style: growth + ops")

second_left, second_right = st.columns(2)

with second_left:
    st.subheader("Cohort Retention")
    image_or_warning("cohort_heatmap.png", f"Cohort heatmap, min cohort size reference: {min_cohort_users}")

with second_right:
    st.subheader("SLA vs Bad Review")
    image_or_warning("bad_review_by_delay.png", "Bad review rate by delay vs estimated delivery")
    image_or_warning("bad_review_by_duration.png", "Bad review rate by overall delivery duration")

st.subheader("Historical A/B Simulation")
st.dataframe(AB_RESULTS, use_container_width=True, hide_index=True)
st.info("Recommendation: continue running or scale gradually, but do not fully launch until logistics cost is justified by retention and CX gains.")

with st.expander("Metric definitions used in this dashboard"):
    st.markdown(
        """
        - `Valid order`: `order_status NOT IN ('canceled', 'unavailable')` and `paid_value > 0`
        - `GMV`: sum of `payment_value` on valid orders
        - `30d repeat`: first-order users who made another valid purchase within 30 days
        - `Late share`: delivered after `order_estimated_delivery_date`
        - `Bad review`: `review_score <= 2`
        """
    )
