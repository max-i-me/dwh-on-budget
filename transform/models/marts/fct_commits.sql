{{
    config(
        materialized='table'
    )
}}

with commits as (
    select * from {{ ref('stg_commits') }}
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
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['c.commit_sha']) }} as commit_key,
        
        -- Natural key
        c.commit_sha,
        
        -- Foreign keys
        r.repo_key,
        u.user_key as author_key,
        d.date_key as commit_date_key,
        
        -- Commit attributes
        c.commit_message,
        c.message_length,
        c.commit_author_name,
        c.commit_author_email,
        
        -- Metrics
        c.comment_count,
        
        -- Timestamps
        c.commit_date,
        c.committer_date,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from commits c
    left join repositories r
        on c.repository_full_name = r.repository_full_name
    left join users u
        on c.author_id = u.user_id
    left join dates d
        on cast(c.commit_date as date) = d.date
)

select * from final
