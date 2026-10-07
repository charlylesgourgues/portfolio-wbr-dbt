-- After deduplication a lead has at most one event per stage (initial lock only).
select lead_id, stage, count(*) as n_events
from {{ ref('int_stage_events_deduplicated') }}
group by lead_id, stage
having count(*) > 1
