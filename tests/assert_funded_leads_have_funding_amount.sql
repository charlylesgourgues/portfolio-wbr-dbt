{{ config(severity='warn') }}

-- A funded lead without a funding row means the fundings record is still in flight
-- (it is recorded after the stage event). funded_amount stays NULL until it lands.
select lead_id, funded_at
from {{ ref('fct_lead_funnel') }}
where is_funded and funded_amount is null
