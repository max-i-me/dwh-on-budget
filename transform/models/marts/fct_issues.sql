{{
    config(
        materialized='table'
    )
}}

with issues as (
    select * from {{ ref('int_issue_lifecycle') }}
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
        {{ dbt_utils.generate_surrogate_key(['i.issue_id']) }} as issue_key,
        
        -- Natural key
        i.issue_id,
        i.issue_number,
        
        -- Foreign keys
        r.repo_key,
        u.user_key as author_key,
        d_created.date_key as created_date_key,
        d_closed.date_key as closed_date_key,
        
        -- Issue attributes
        i.issue_title,
        i.issue_state,
        i.is_closed,
        i.is_assigned,
        
        -- Labels (label_list removed - use stg_issue_labels for detailed label info)
        i.label_count,
        i.is_bug,
        i.is_enhancement,
        
        -- Metrics
        i.comment_count,
        i.time_to_close_hours,
        i.time_to_first_response_hours,
        
        -- Timestamps
        i.created_at,
        i.updated_at,
        i.closed_at,
        i.first_comment_at,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from issues i
    left join repositories r
        on i.repository_full_name = r.repository_full_name
    left join users u
        on i.author_id = u.user_id
    left join dates d_created
        on cast(i.created_at as date) = d_created.date
    left join dates d_closed
        on cast(i.closed_at as date) = d_closed.date
)

select * from final
