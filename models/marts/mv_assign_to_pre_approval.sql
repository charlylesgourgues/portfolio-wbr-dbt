{{ config(materialized='metric_view') }}
{#-
    Unity Catalog metric view on fct_lead_funnel (the body below is the metric view YAML).
    Single definition of the assign -> pre-approval conversion, shared by Power BI and
    Genie. The rate is always sum / sum, never an average of rates, so it is correct at any
    grain (week, month, year) and under any dimension filter.

    The maturity cap is part of the MEASURE, not of the rows: fct_lead_funnel stays at one
    row per lead, so `assigns` can never be double counted and each rate names its cap
    (assign_to_pre_approval_rate_21d). The caps come from the `maturity_caps_days` var.
    A lead converts within a cap of N days when days_assigned_to_pre_approved <= N
    (calendar days, inclusive, defined once in fct_lead_funnel).

    The uncapped pair (pre_approvals, assign_to_pre_approval_rate) counts any pre-approval,
    whenever it happened. It is meant for all-time totals, not for comparing periods.
-#}
version: 1.1
comment: >
  Assign to pre-approval conversion of the lead funnel. Cohort = the period in which the
  lead was assigned. Denominator (assigns) = every lead assigned in the period, duplicates
  included unless filtered on is_duplicate. Numerator (pre_approvals_<N>d) = those
  pre-approved within N calendar days of the assign, inclusive, N being the maturity cap
  (one measure per cap). Recent periods are understated until mature_assigns_share_<N>d
  reaches 100%.
source: {{ ref('fct_lead_funnel') }}
filter: is_assigned

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
    expr: count(1)
    comment: Leads assigned in the period (denominator, independent of the maturity cap).
  - name: pre_approvals
    expr: count(1) filter (where is_pre_approved)
    comment: >
      Assigned leads pre-approved at any time, with no maturity cap. Not comparable across
      periods: recent cohorts have had less time to convert. Use the capped measures to
      compare periods.
  - name: assign_to_pre_approval_rate
    expr: try_divide(MEASURE(pre_approvals), MEASURE(assigns))
    comment: >
      Uncapped share of assigned leads pre-approved at any time. Understated for recent
      periods; use assign_to_pre_approval_rate_<N>d to compare periods.
    format:
      type: percentage
{% for cap in var('maturity_caps_days', [7, 14, 21, 35, 45]) %}
  - name: pre_approvals_{{ cap }}d
    expr: count(1) filter (where days_assigned_to_pre_approved <= {{ cap }})
    comment: Assigned leads pre-approved within {{ cap }} calendar days of the assign (numerator).
  - name: assign_to_pre_approval_rate_{{ cap }}d
    expr: try_divide(MEASURE(pre_approvals_{{ cap }}d), MEASURE(assigns))
    comment: Share of assigned leads pre-approved within {{ cap }} calendar days of the assign.
    format:
      type: percentage
  - name: mature_assigns_share_{{ cap }}d
    expr: try_divide(count(1) filter (where datediff(current_date(), assigned_date) > {{ cap }}), MEASURE(assigns))
    comment: Share of the cohort whose {{ cap }}-day window is fully observed; 100% means the period is complete.
    format:
      type: percentage
{% endfor %}
