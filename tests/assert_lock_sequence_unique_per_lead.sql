-- A lock position (1, 2, ...) appears once per lead.
select lead_id, lock_sequence, count(*) as n_locks
from {{ ref('int_rate_lock_chains') }}
group by lead_id, lock_sequence
having count(*) > 1
