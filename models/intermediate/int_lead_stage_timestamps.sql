{#-
    One row per lead (duplicates included, flagged) with one timestamp per funnel stage,
    pivoted from the cleaned events. Base of the accumulating snapshot fct_lead_funnel.
    Stage timestamps come from event_ts; rate_locked_at is the initial lock.
-#}
with stage_timestamps as (

    select
        lead_id,
        min(case when stage = 'lead_created' then event_ts end) as lead_created_at,
        min(case when stage = 'assigned' then event_ts end) as assigned_at,
        min(case when stage = 'pre_approved' then event_ts end) as pre_approved_at,
        min(case when stage = 'rate_locked' then event_ts end) as rate_locked_at,
        min(case when stage = 'funded' then event_ts end) as funded_at,
        min(case when stage = 'closed_lost' then event_ts end) as closed_lost_at
    from {{ ref('int_stage_events_deduplicated') }}
    group by lead_id

)

select
    leads.lead_id,
    leads.created_at,
    leads.status,
    leads.lost_reason,
    leads.closed_at,
    flags.is_duplicate,
    flags.original_lead_id,
    flags.duplicate_group_id,
    stage_timestamps.lead_created_at,
    stage_timestamps.assigned_at,
    stage_timestamps.pre_approved_at,
    stage_timestamps.rate_locked_at,
    stage_timestamps.funded_at,
    stage_timestamps.closed_lost_at,
    case
        when stage_timestamps.funded_at is not null then 'funded'
        when stage_timestamps.rate_locked_at is not null then 'rate_locked'
        when stage_timestamps.pre_approved_at is not null then 'pre_approved'
        when stage_timestamps.assigned_at is not null then 'assigned'
        else 'lead_created'
    end as furthest_stage_reached
from {{ ref('stg_leads') }} as leads
left join {{ ref('int_leads_duplicate_flags') }} as flags
    on flags.lead_id = leads.lead_id
left join stage_timestamps
    on stage_timestamps.lead_id = leads.lead_id
