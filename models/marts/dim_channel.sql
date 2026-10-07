{#-
    One row per acquisition channel. `channel` is the original CRM value; `channel_group`
    is a business grouping added on top of it. A new channel without a mapping falls into
    'other' and fails the accepted_values test, which forces an explicit mapping.
-#}
with channels as (

    select distinct channel
    from {{ ref('stg_leads') }}
    where channel is not null

)

select
    channel,
    case channel
        when 'paid_search' then 'paid'
        when 'marketplace_listing' then 'paid'
        when 'organic_web' then 'organic'
        when 'referral' then 'referral'
        when 'partner_agent' then 'referral'
        else 'other'
    end as channel_group
from channels
