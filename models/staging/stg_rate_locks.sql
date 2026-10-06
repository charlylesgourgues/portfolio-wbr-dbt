select
    cast(lock_id as int) as lock_id,
    cast(lead_id as int) as lead_id,
    cast(locked_at as timestamp) as locked_at,
    cast(lock_period_days as int) as lock_period_days,
    cast(interest_rate as decimal(6, 4)) as interest_rate,
    cast(loan_amount as decimal(18, 2)) as loan_amount,
    cast(expires_at as timestamp) as expires_at,
    cast(coalesce(extension_days, 0) as int) as extension_days,
    status,
    cast(updated_at as timestamp) as updated_at
from {{ source('crm', 'rate_locks') }}
where not coalesce(_fivetran_deleted, false)
