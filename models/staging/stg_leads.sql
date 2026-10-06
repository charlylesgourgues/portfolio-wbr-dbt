with source as (

    select * from {{ source('crm', 'leads') }}
    where not coalesce(_fivetran_deleted, false)

),

cleaned as (

    select
        cast(lead_id as int) as lead_id,
        cast(created_at as timestamp) as created_at,
        trim(first_name) as first_name,
        trim(last_name) as last_name,
        nullif(lower(trim(email)), '') as email,
        -- digits only; drop the US country code so "+12125550147" = "(212) 555-0147"
        nullif(regexp_replace(regexp_replace(phone, '[^0-9]', ''), '^1(?=[0-9]{10}$)', ''), '') as phone,
        trim(channel) as channel,
        trim(loan_purpose) as loan_purpose,
        upper(trim(property_state)) as property_state,
        trim(property_zip) as property_zip,
        cast(est_loan_amount as decimal(18, 2)) as est_loan_amount,
        trim(credit_band) as credit_band,
        current_stage,
        status,
        lost_reason,
        cast(assigned_lo_id as int) as assigned_lo_id,
        cast(closed_at as timestamp) as closed_at,
        cast(updated_at as timestamp) as updated_at
    from source

)

select * from cleaned
