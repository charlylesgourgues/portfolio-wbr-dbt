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

    -- stage-to-stage durations
    {{ dbt.datediff('timestamps.lead_created_at', 'timestamps.assigned_at', 'second') }} / 60.0
        as minutes_lead_to_assigned,
    {{ dbt.datediff('timestamps.assigned_at', 'timestamps.pre_approved_at', 'second') }} / 3600.0
        as hours_assigned_to_pre_approved,
    {{ dbt.datediff('timestamps.pre_approved_at', 'timestamps.rate_locked_at', 'second') }} / 3600.0
        as hours_pre_approved_to_rate_locked,
    {{ dbt.datediff('timestamps.rate_locked_at', 'timestamps.funded_at', 'second') }} / 3600.0
        as hours_rate_locked_to_funded,
    {{ dbt.datediff('timestamps.lead_created_at', 'timestamps.funded_at', 'second') }} / 3600.0
        as hours_lead_to_funded,

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
