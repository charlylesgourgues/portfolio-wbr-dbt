{#-
    One row per US state (DC included), attached to the sales team and region that cover
    it. The state-to-team mapping comes from the teams' `covered_states` list. ZIP codes
    are too granular for a dimension and stay on the fact.
-#}
with team_states as (

    select
        team_id,
        team_name,
        region,
        trim(state_code) as state_code
    from {{ ref('stg_teams') }}
    lateral view explode(split(covered_states, ',')) states as state_code

)

select
    state_code,
    team_id,
    team_name,
    region
from team_states
