-- A duplicate is always created after its original, and never points to itself.
select flags.lead_id
from {{ ref('int_leads_duplicate_flags') }} as flags
inner join {{ ref('stg_leads') }} as duplicate on duplicate.lead_id = flags.lead_id
inner join {{ ref('stg_leads') }} as original on original.lead_id = flags.original_lead_id
where flags.is_duplicate
    and (
        flags.original_lead_id = flags.lead_id
        or original.created_at > duplicate.created_at
    )
