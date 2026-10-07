{#-
    Calendar dimension, one row per day. Weeks run Monday to Sunday (ISO), the grain used
    for the Weekly Business Review. The range covers the data (from 2024-10-01) with room
    to grow; widen it through the `dim_date_start` / `dim_date_end` vars.
-#}
with spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('dim_date_start', '2024-10-01') ~ "' as date)",
        end_date="cast('" ~ var('dim_date_end', '2027-01-01') ~ "' as date)"
    ) }}

),

days as (

    select cast(date_day as date) as date_day from spine

)

select
    cast(date_format(date_day, 'yyyyMMdd') as int) as date_key,
    date_day,
    year(date_day) as year_number,
    quarter(date_day) as quarter_number,
    concat(year(date_day), '-Q', quarter(date_day)) as year_quarter,
    month(date_day) as month_number,
    date_format(date_day, 'MMMM') as month_name,
    date_format(date_day, 'yyyy-MM') as year_month,
    cast({{ dbt.date_trunc('month', 'date_day') }} as date) as month_start_date,
    cast({{ dbt.date_trunc('week', 'date_day') }} as date) as week_start_date,
    date_add(cast({{ dbt.date_trunc('week', 'date_day') }} as date), 6) as week_end_date,
    weekofyear(date_day) as iso_week_number,
    year(date_add(cast({{ dbt.date_trunc('week', 'date_day') }} as date), 3)) as iso_year_number,
    weekday(date_day) + 1 as day_of_week_number,
    date_format(date_day, 'EEEE') as day_name,
    weekday(date_day) >= 5 as is_weekend
from days
