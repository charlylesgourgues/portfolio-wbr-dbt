select
    cast(lo_id as int) as lo_id,
    trim(first_name) as first_name,
    trim(last_name) as last_name,
    lower(trim(email)) as email,
    cast(team_id as int) as team_id,
    cast(hire_date as date) as hire_date,
    cast(termination_date as date) as termination_date,
    cast(is_active as boolean) as is_active,
    cast(updated_at as timestamp) as updated_at
from {{ source('crm', 'loan_officers') }}
where not coalesce(_fivetran_deleted, false)
