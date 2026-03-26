{{
    config(
        materialized='table'
    )
}}

-- Generate date dimension using macro
{{ generate_date_spine(
    start_date=var('date_spine_start', '2020-01-01'),
    end_date=var('date_spine_end', '2026-12-31')
) }}
