{#-
    Assign -> pre-approval conversion with maturity caps. Grain: one row per assigned lead
    and maturity cap (7, 14, 21, 35, 45 days; override with the `maturity_caps_days` var),
    so the cap is a dimension the report can switch on. Always filter the cap to ONE value:
    summing across caps counts every lead once per cap.

    Cohort = assigned_date. Every assigned lead of the cohort is in the denominator
    (assign_flag = 1), including leads that have not had the full cap to convert yet.
    The numerator counts leads pre-approved within the cap, measured in calendar days
    (days_assigned_to_pre_approved <= cap, inclusive; see fct_lead_funnel). Recent cohorts
    are therefore understated until they mature: is_mature says whether the lead's whole
    cap window is in the past, and the share of mature rows tells a period is complete.
    A window is complete once the day assigned_date + cap has ended, hence the strict `>`.

    Duplicates are kept and exposed through is_duplicate: reporting on real demand
    filters is_duplicate = false.
-#}
with leads as (

    select * from {{ ref('fct_lead_funnel') }}
    where is_assigned

),

caps as (

    {% for cap in var('maturity_caps_days', [7, 14, 21, 35, 45]) -%}
    select {{ cap }} as maturity_cap_days
    {% if not loop.last %}union all{% endif %}
    {% endfor %}

)

select
    leads.lead_id,
    caps.maturity_cap_days,

    -- cohort date and dimension keys
    leads.assigned_date,
    leads.assigned_at,
    leads.channel,
    leads.loan_purpose,
    leads.property_state,
    leads.credit_band,
    leads.assigned_lo_id,
    leads.is_duplicate,

    -- maturity of the lead's cap window, in calendar days
    {{ dbt.datediff('leads.assigned_date', 'cast(' ~ dbt.current_timestamp() ~ ' as date)', 'day') }}
        > caps.maturity_cap_days as is_mature,

    -- additive measures: the rate is sum(pre_approval_flag) / sum(assign_flag)
    1 as assign_flag,
    case when leads.days_assigned_to_pre_approved <= caps.maturity_cap_days then 1 else 0 end
        as pre_approval_flag

from leads
cross join caps
