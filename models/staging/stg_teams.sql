select
    cast(team_id as int) as team_id,
    trim(team_name) as team_name,
    trim(region) as region,
    covered_states,
    cast(updated_at as timestamp) as updated_at
from {{ source('crm', 'teams') }}
where not coalesce(_fivetran_deleted, false)
