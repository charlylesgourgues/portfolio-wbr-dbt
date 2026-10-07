-- Each loan officer has exactly one current version and non-overlapping validity ranges.
with current_versions as (

    select lo_id, count(*) as n_current
    from {{ ref('dim_loan_officer') }}
    where is_current
    group by lo_id

),

overlaps as (

    select a.lo_id
    from {{ ref('dim_loan_officer') }} as a
    inner join {{ ref('dim_loan_officer') }} as b
        on a.lo_id = b.lo_id
        and a.loan_officer_key <> b.loan_officer_key
        and a.valid_from < b.valid_to
        and b.valid_from < a.valid_to

)

select lo_id from current_versions where n_current <> 1
union all
select lo_id from overlaps
