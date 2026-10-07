{#-
    One row per rate lock, with its position in the lead's lock chain and a comparison
    against the previous lock (a lead can re-lock after the first lock expired).
    Meant for lock-dedicated reporting: re-lock rate, rate delta vs previous lock, etc.

    expires_at already includes extension_days in the source, so it is the effective
    expiry; the original expiry is rebuilt from locked_at + lock_period_days.
-#}
with locks as (

    select * from {{ ref('stg_rate_locks') }}

),

sequenced as (

    select
        *,
        row_number() over (partition by lead_id order by locked_at, lock_id) as lock_sequence,
        count(*) over (partition by lead_id) as locks_in_chain,
        lag(lock_id) over (partition by lead_id order by locked_at, lock_id) as previous_lock_id,
        lag(status) over (partition by lead_id order by locked_at, lock_id) as previous_lock_status,
        lag(interest_rate) over (partition by lead_id order by locked_at, lock_id) as previous_interest_rate,
        lag(loan_amount) over (partition by lead_id order by locked_at, lock_id) as previous_loan_amount,
        lag(expires_at) over (partition by lead_id order by locked_at, lock_id) as previous_expires_at
    from locks

)

select
    lock_id,
    lead_id,
    lock_sequence,
    locks_in_chain,
    lock_sequence = 1 as is_initial_lock,
    lock_sequence > 1 as is_relock,
    lock_sequence = locks_in_chain as is_final_lock,
    locked_at,
    lock_period_days,
    extension_days,
    extension_days > 0 as was_extended,
    locked_at + make_interval(0, 0, 0, lock_period_days) as original_expires_at,
    expires_at as effective_expires_at,
    status,
    interest_rate,
    loan_amount,
    previous_lock_id,
    previous_lock_status,
    previous_interest_rate,
    interest_rate - previous_interest_rate as rate_delta_vs_previous,
    loan_amount - previous_loan_amount as loan_amount_delta_vs_previous,
    previous_expires_at,
    {{ dbt.datediff('previous_expires_at', 'locked_at', 'second') }} / 86400.0 as days_since_previous_expiry
from sequenced
