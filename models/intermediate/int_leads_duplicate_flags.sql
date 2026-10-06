{#-
    Flags duplicate leads WITHOUT removing them, so duplicates can be reported on.

    A lead is a duplicate when an earlier lead shares its normalized email or phone and
    was created at most `duplicate_window_hours` before it. The original is the earliest
    matching lead; when that match is itself a duplicate, one hop is followed to reach
    the root original. Detection is independent of lost_reason (not every duplicate is
    closed with lost_reason = 'duplicate').
-#}
{%- set duplicate_window_hours = 72 -%}

with leads as (

    select lead_id, created_at, email, phone
    from {{ ref('stg_leads') }}

),

candidate_matches as (

    select
        later.lead_id,
        earlier.lead_id as matched_lead_id,
        (earlier.email is not null and earlier.email = later.email) as email_match,
        (earlier.phone is not null and earlier.phone = later.phone) as phone_match,
        row_number() over (
            partition by later.lead_id
            order by earlier.created_at, earlier.lead_id
        ) as match_rank
    from leads as later
    inner join leads as earlier
        on (
            earlier.created_at < later.created_at
            or (earlier.created_at = later.created_at and earlier.lead_id < later.lead_id)
        )
        and later.created_at <= earlier.created_at + interval {{ duplicate_window_hours }} hours
        and (
            (earlier.email is not null and earlier.email = later.email)
            or (earlier.phone is not null and earlier.phone = later.phone)
        )

),

first_match as (

    select * from candidate_matches where match_rank = 1

),

resolved as (

    select
        direct.lead_id,
        coalesce(upstream.matched_lead_id, direct.matched_lead_id) as original_lead_id,
        case
            when direct.email_match and direct.phone_match then 'email_and_phone'
            when direct.email_match then 'email'
            else 'phone'
        end as match_type
    from first_match as direct
    left join first_match as upstream
        on upstream.lead_id = direct.matched_lead_id

),

duplicate_counts as (

    select original_lead_id, count(*) as duplicate_count
    from resolved
    group by original_lead_id

)

select
    leads.lead_id,
    resolved.lead_id is not null as is_duplicate,
    resolved.original_lead_id,
    coalesce(resolved.original_lead_id, leads.lead_id) as duplicate_group_id,
    resolved.match_type,
    case
        when resolved.lead_id is not null
            then {{ dbt.datediff('originals.created_at', 'leads.created_at', 'second') }} / 3600.0
    end as hours_since_original,
    coalesce(duplicate_counts.duplicate_count, 0) as duplicate_count
from leads
left join resolved
    on resolved.lead_id = leads.lead_id
left join leads as originals
    on originals.lead_id = resolved.original_lead_id
left join duplicate_counts
    on duplicate_counts.original_lead_id = leads.lead_id
