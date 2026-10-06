select
    cast(assignment_id as int) as assignment_id,
    cast(lead_id as int) as lead_id,
    cast(lo_id as int) as lo_id,
    cast(assigned_at as timestamp) as assigned_at,
    cast(unassigned_at as timestamp) as unassigned_at,
    assignment_reason,
    cast(updated_at as timestamp) as updated_at
from {{ source('crm', 'lead_assignments') }}
where not coalesce(_fivetran_deleted, false)
