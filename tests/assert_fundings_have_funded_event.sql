{{ config(severity='warn') }}

-- A funding without its `funded` stage event means the LOS event is late-arriving.
-- Not an error: fct_lead_funnel relies on the event, so the lead counts as funded
-- once the event lands. The warning makes the lag visible.
select fundings.lead_id, fundings.funded_at, fundings.recorded_at
from {{ ref('stg_fundings') }} as fundings
left join {{ ref('int_lead_stage_timestamps') }} as timestamps
    on timestamps.lead_id = fundings.lead_id
where timestamps.funded_at is null
