{#-
    SCD2 loan officer dimension built from snap_loan_officers: one row per version of a
    loan officer (team, activity or termination change).

    KNOWN LIMITATION: the CRM only keeps the current state and the snapshot history
    starts at its first run, so the first version of each loan officer is treated as valid
    since the beginning of time (valid_from = 1900-01-01). Team transfers before the
    first snapshot run are not reconstructed.

    A row `Unassigned` (lo_id = -1) catches leads that never got a loan officer.
-#}
with versions as (

    select
        *,
        row_number() over (partition by lo_id order by dbt_valid_from) as version_number
    from {{ ref('snap_loan_officers') }}

),

loan_officers as (

    select
        versions.dbt_scd_id as loan_officer_key,
        versions.lo_id,
        versions.first_name,
        versions.last_name,
        concat(versions.first_name, ' ', versions.last_name) as full_name,
        versions.email,
        versions.team_id,
        teams.team_name,
        teams.region,
        versions.hire_date,
        versions.termination_date,
        versions.is_active,
        case
            when versions.version_number = 1 then cast('1900-01-01' as timestamp)
            else versions.dbt_valid_from
        end as valid_from,
        coalesce(versions.dbt_valid_to, cast('9999-12-31' as timestamp)) as valid_to,
        versions.dbt_valid_to is null as is_current
    from versions
    left join {{ ref('stg_teams') }} as teams
        on teams.team_id = versions.team_id

),

unassigned as (

    select
        {{ dbt_utils.generate_surrogate_key(["'unassigned'"]) }} as loan_officer_key,
        -1 as lo_id,
        'Unassigned' as first_name,
        cast(null as string) as last_name,
        'Unassigned' as full_name,
        cast(null as string) as email,
        cast(null as int) as team_id,
        cast(null as string) as team_name,
        cast(null as string) as region,
        cast(null as date) as hire_date,
        cast(null as date) as termination_date,
        cast(null as boolean) as is_active,
        cast('1900-01-01' as timestamp) as valid_from,
        cast('9999-12-31' as timestamp) as valid_to,
        true as is_current

)

select * from loan_officers
union all
select * from unassigned
