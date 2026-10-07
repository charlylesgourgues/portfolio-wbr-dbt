-- One row per loan purpose (purchase / refinance).
select distinct
    loan_purpose
from {{ ref('stg_leads') }}
where loan_purpose is not null
