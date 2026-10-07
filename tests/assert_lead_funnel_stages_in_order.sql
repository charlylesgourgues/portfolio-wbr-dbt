-- Stage timestamps must be chronological and funnel flags consistent with the status.
select lead_id
from {{ ref('fct_lead_funnel') }}
where assigned_at < lead_created_at
    or pre_approved_at < assigned_at
    or rate_locked_at < pre_approved_at
    or funded_at < rate_locked_at
    or (status = 'funded') <> is_funded
    or (funded_amount is not null and not is_funded)
