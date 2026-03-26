{{
    config(
        materialized='table'
    )
}}

with stargazers as (
    select * from {{ ref('stg_stargazers') }}
),

repositories as (
    select * from {{ ref('dim_repositories') }}
),

users as (
    select * from {{ ref('dim_users') }}
),

dates as (
    select * from {{ ref('dim_dates') }}
),

final as (
    select
        -- Composite key
        {{ dbt_utils.generate_surrogate_key(['s.user_id', 's.repository_full_name']) }} as stargazer_key,
        
        -- Foreign keys
        r.repo_key,
        u.user_key,
        d.date_key as starred_date_key,
        
        -- Timestamp
        s.starred_at,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from stargazers s
    left join repositories r
        on s.repository_full_name = r.repository_full_name
    left join users u
        on s.user_id = u.user_id
    left join dates d
        on cast(s.starred_at as date) = d.date
)

select * from final
