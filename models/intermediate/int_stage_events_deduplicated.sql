{#-
    Funnel events cleaned for the stage-transition fact:
      1. double-posted events (same lead_id + stage + event_ts, different event_id) are
         collapsed, keeping the lowest event_id;
      2. only the initial rate_locked event is kept per lead: a re-lock is still the same
         lead having locked. Re-locks are analysed in int_rate_lock_chains;
      3. events are sequenced by event_ts (not recorded_at) so late LOS events land in the
         right place in the funnel.
-#}
{%- set late_event_threshold_hours = var('late_event_threshold_hours', 1) -%}

with exact_duplicates_removed as (

    select
        *,
        row_number() over (
            partition by lead_id, stage, event_ts
            order by event_id
        ) as posting_rank
    from {{ ref('stg_lead_stage_events') }}

),

initial_lock_only as (

    select
        *,
        row_number() over (
            partition by lead_id, stage
            order by event_ts, event_id
        ) as stage_occurrence
    from exact_duplicates_removed
    where posting_rank = 1

),

kept as (

    select * from initial_lock_only
    where stage <> 'rate_locked' or stage_occurrence = 1

)

select
    event_id,
    lead_id,
    stage,
    event_ts,
    lo_id,
    source_system,
    recorded_at,
    {{ dbt.datediff('event_ts', 'recorded_at', 'second') }} / 3600.0 as recorded_lag_hours,
    {{ dbt.datediff('event_ts', 'recorded_at', 'second') }} / 3600.0 > {{ late_event_threshold_hours }} as is_late_arriving,
    row_number() over (
        partition by lead_id
        order by
            event_ts,
            case stage
                when 'lead_created' then 1
                when 'assigned' then 2
                when 'pre_approved' then 3
                when 'rate_locked' then 4
                when 'funded' then 5
                else 6
            end
    ) as event_sequence
from kept
