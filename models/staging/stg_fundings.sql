select
    cast(funding_id as int) as funding_id,
    cast(lead_id as int) as lead_id,
    cast(lock_id as int) as lock_id,
    cast(funded_at as timestamp) as funded_at,
    cast(funded_amount as decimal(18, 2)) as funded_amount,
    cast(recorded_at as timestamp) as recorded_at
from {{ source('crm', 'fundings') }}
where not coalesce(_fivetran_deleted, false)
