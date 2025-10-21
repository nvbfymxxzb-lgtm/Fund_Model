"""
app.py – Streamlit interface for the PE portfolio model.
Run locally:  streamlit run app.py
"""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.graph_objects as go
from model import build_cash_flows, calculate_irr, validate_inputs
from presets import PRESETS

st.set_page_config(page_title="PE Portfolio Model", layout="wide")
st.title("Private Equity Portfolio Model")

with st.sidebar:
    st.header("Scenario Selection")
    scenario = st.radio("Choose preset", list(PRESETS.keys()) + ["Custom"])

    if scenario != "Custom":
        params = PRESETS[scenario]
        target_moic = params["target_moic"]
        holding_period = params["holding_period"]
        commitment = params["commitment"]
    else:
        target_moic = st.slider("Target MOIC", 1.2, 5.0, 2.5, 0.1)
        holding_period = st.slider("Holding Period (years)", 5, 12, 8, 1)
        commitment = st.number_input("Commitment ($)", 100_000_000, 2_000_000_000, 700_000_000, step=50_000_000)

    target_moic, holding_period, warnings = validate_inputs(target_moic, holding_period)
    for w in warnings:
        st.warning(w)

cash_flows, total_called, total_distributions = build_cash_flows(commitment, target_moic, holding_period)
actual_moic = total_distributions / total_called if total_called > 0 else np.nan
irr_pct = calculate_irr([0.0] + cash_flows[1:])
deployment_pct = (total_called / commitment * 100.0) if commitment > 0 else 0.0
profit_generated = total_distributions - total_called

# Primary KPIs
col1, col2, col3 = st.columns(3)
col1.metric("IRR", f"{irr_pct:.1f}%", help="Internal Rate of Return (annualized)")
col2.metric("MOIC", f"{actual_moic:.2f}x", help="Multiple on Invested Capital")
col3.metric("Deployed", f"{deployment_pct:.0f}%", help="Capital called as % of commitment")

# Secondary KPIs
c4, c5, c6 = st.columns(3)
c4.metric("Total Called", f"${total_called/1e6:,.1f}M")
c5.metric("Total Distributions", f"${total_distributions/1e6:,.1f}M")
c6.metric("Profit Generated", f"${profit_generated/1e6:,.1f}M")

years = list(range(len(cash_flows)))
df = pd.DataFrame({
    "Year": years,
    "Capital Calls": [cf if (i>=1 and i<=4 and cf<0) else (-abs(cf) if (i>=1 and i<=4) else 0.0) for i, cf in enumerate(cash_flows)],
    "Distributions": [cf if cf>0 else 0.0 for cf in cash_flows]
})
df["Net CF"] = df["Distributions"] + df["Capital Calls"]

st.subheader("Cash Flow Timeline")
fig = go.Figure()
fig.add_trace(go.Bar(x=df["Year"], y=df["Capital Calls"], name="Capital Calls"))
fig.add_trace(go.Bar(x=df["Year"], y=df["Distributions"], name="Distributions"))
fig.update_layout(barmode='relative', xaxis_title="Year", yaxis_title="Cash Flow ($)", legend_title="Legend")
st.plotly_chart(fig, use_container_width=True)

st.subheader("Yearly Cash Flows")
st.dataframe(df, use_container_width=True)

st.caption("IRR uses bisection; distribution timing drives differences across MOICs.")