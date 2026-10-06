-- Raw events: late LOS events and double-posted events are NOT resolved here;
-- deduplication and ordering by event_ts happen in the intermediate layer.
select
    cast(event_id as int) as event_id,
    cast(lead_id as int) as lead_id,
    stage,
    cast(event_ts as timestamp) as event_ts,
    cast(lo_id as int) as lo_id,
    source_system,
    cast(recorded_at as timestamp) as recorded_at
from {{ source('crm', 'lead_stage_events') }}
where not coalesce(_fivetran_deleted, false)
