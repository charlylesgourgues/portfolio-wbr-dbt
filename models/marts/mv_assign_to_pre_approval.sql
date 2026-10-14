{{ config(materialized='metric_view') }}
{#-
    Unity Catalog metric view over fct_assign_to_pre_approval (the body below is the
    metric view YAML). Single definition of the assign -> pre-approval conversion, shared
    by Power BI and Genie. The rate is always sum / sum, never an average of rates, so it is
    correct at any grain (week, month, year) and under any dimension filter.
-#}
version: 1.1
comment: >
  Assign to pre-approval conversion of the lead funnel. Cohort = the period in which the
  lead was assigned. Denominator = every lead assigned in the period (duplicates included
  unless filtered on is_duplicate). Numerator = leads pre-approved within the maturity cap,
  in calendar days after the assign, inclusive. Always filter maturity_cap_days to a single
  value (7, 14, 21, 35 or 45): each lead appears once per cap. Recent periods are
  understated until mature_assigns_share reaches 100%.
source: {{ ref('fct_assign_to_pre_approval') }}

joins:
  - name: channel_dim
    source: {{ ref('dim_channel') }}
    on: source.channel = channel_dim.channel
  - name: geography_dim
    source: {{ ref('dim_geography') }}
    on: source.property_state = geography_dim.state_code

dimensions:
  - name: assigned_week
    expr: date_trunc('week', assigned_date)
    comment: Monday of the week the lead was assigned (WBR grain).
  - name: assigned_month
    expr: date_trunc('month', assigned_date)
    comment: First day of the month the lead was assigned.
  - name: assigned_year
    expr: date_trunc('year', assigned_date)
    comment: First day of the year the lead was assigned.
  - name: maturity_cap_days
    expr: maturity_cap_days
    comment: Maturity cap in calendar days (7, 14, 21, 35, 45). Select exactly one value.
  - name: is_duplicate
    expr: is_duplicate
    comment: True for leads flagged as duplicates; filter to false for real demand.
  - name: channel
    expr: channel
  - name: channel_group
    expr: channel_dim.channel_group
  - name: loan_purpose
    expr: loan_purpose
  - name: credit_band
    expr: credit_band
  - name: property_state
    expr: property_state
  - name: team_name
    expr: geography_dim.team_name
    comment: Sales team covering the property state.
  - name: region
    expr: geography_dim.region
  - name: assigned_lo_id
    expr: assigned_lo_id

measures:
  - name: assigns
    expr: sum(assign_flag)
    comment: Leads assigned in the period (denominator).
  - name: pre_approvals
    expr: sum(pre_approval_flag)
    comment: Assigned leads pre-approved within the maturity cap (numerator).
  - name: assign_to_pre_approval_rate
    expr: try_divide(MEASURE(pre_approvals), MEASURE(assigns))
    comment: Share of assigned leads pre-approved within the maturity cap.
    format:
      type: percentage
  - name: mature_assigns_share
    expr: try_divide(sum(case when is_mature then 1 else 0 end), sum(assign_flag))
    comment: Share of the cohort whose whole cap window is observed; 100% means the period is complete.
    format:
      type: percentage
