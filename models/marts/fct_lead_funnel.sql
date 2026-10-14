{#-
    Accumulating snapshot of the lead funnel: one row per lead (duplicates included and
    flagged), one timestamp per stage, stage-to-stage durations and the final status.
    Rows are rebuilt on every run, so stage timestamps fill in as leads progress.

    Reporting on real demand should filter `not is_duplicate`; duplicate reporting uses
    is_duplicate / original_lead_id / duplicate_group_id.
-#}
with leads as (

    select * from {{ ref('stg_leads') }}

),

timestamps as (

    select * from {{ ref('int_lead_stage_timestamps') }}

),

duplicate_flags as (

    select * from {{ ref('int_leads_duplicate_flags') }}

),

locks as (

    select
        lead_id,
        count(*) as lock_count
    from {{ ref('int_rate_lock_chains') }}
    group by lead_id

),

fundings as (

    select lead_id, funded_amount
    from {{ ref('stg_fundings') }}

)

select
    leads.lead_id,

    -- lead attributes (keys to the dimensions)
    cast(leads.created_at as date) as created_date,
    -- cohort date of the assign-based funnel metrics (NULL until assigned)
    cast(timestamps.assigned_at as date) as assigned_date,
    leads.channel,
    leads.loan_purpose,
    leads.property_state,
    leads.credit_band,
    leads.assigned_lo_id,
    leads.est_loan_amount,

    -- duplicates
    duplicate_flags.is_duplicate,
    duplicate_flags.original_lead_id,
    duplicate_flags.duplicate_group_id,

    -- one timestamp per stage (NULL when the stage was not reached)
    timestamps.lead_created_at,
    timestamps.assigned_at,
    timestamps.pre_approved_at,
    timestamps.rate_locked_at,
    timestamps.funded_at,
    timestamps.closed_lost_at,

    -- stage reached flags, for conversion rates
    timestamps.assigned_at is not null as is_assigned,
    timestamps.pre_approved_at is not null as is_pre_approved,
    timestamps.rate_locked_at is not null as is_rate_locked,
    timestamps.funded_at is not null as is_funded,

    -- Stage-to-stage durations. Speed-to-assign is in minutes (the Southeast story moves
    -- from ~10 min to ~4 h); every other duration is in CALENDAR days: the number of
    -- midnights crossed between the two stages, so 23:00 -> 01:00 next day is 1 day.
    -- This is the single source of truth for maturity caps ("converted within N days
    -- = days_* <= N"), so metrics never re-implement the day arithmetic.
    {{ dbt.datediff('timestamps.lead_created_at', 'timestamps.assigned_at', 'second') }} / 60.0
        as minutes_lead_to_assigned,
    {{ dbt.datediff('cast(timestamps.assigned_at as date)', 'cast(timestamps.pre_approved_at as date)', 'day') }}
        as days_assigned_to_pre_approved,
    {{ dbt.datediff('cast(timestamps.pre_approved_at as date)', 'cast(timestamps.rate_locked_at as date)', 'day') }}
        as days_pre_approved_to_rate_locked,
    {{ dbt.datediff('cast(timestamps.rate_locked_at as date)', 'cast(timestamps.funded_at as date)', 'day') }}
        as days_rate_locked_to_funded,
    {{ dbt.datediff('cast(timestamps.lead_created_at as date)', 'cast(timestamps.funded_at as date)', 'day') }}
        as days_lead_to_funded,

    -- final outcome
    timestamps.furthest_stage_reached,
    leads.status,
    leads.lost_reason,
    leads.closed_at,

    -- locks and funding
    coalesce(locks.lock_count, 0) as lock_count,
    -- Only set once the funded stage event has landed: a funding whose LOS event is
    -- still in flight (late-arriving) stays out until the event arrives.
    case when timestamps.funded_at is not null then fundings.funded_amount end as funded_amount

from leads
inner join timestamps
    on timestamps.lead_id = leads.lead_id
inner join duplicate_flags
    on duplicate_flags.lead_id = leads.lead_id
left join locks
    on locks.lead_id = leads.lead_id
left join fundings
    on fundings.lead_id = leads.lead_id
