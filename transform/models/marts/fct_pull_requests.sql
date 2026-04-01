{{
    config(
        materialized='table'
    )
}}

with pull_requests as (
    select * from {{ ref('int_pr_with_reviews') }}
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
        {{ dbt_utils.generate_surrogate_key(['pr.pull_request_id']) }} as pr_key,
        
        -- Natural key
        pr.pull_request_id,
        pr.pr_number,
        
        -- Foreign keys
        r.repo_key,
        u.user_key as author_key,
        d_created.date_key as created_date_key,
        d_merged.date_key as merged_date_key,
        d_closed.date_key as closed_date_key,
        
        -- PR attributes
        pr.pr_title,
        pr.pr_state,
        pr.is_merged,
        pr.is_draft,
        pr.is_closed,
        pr.is_closed_without_merge,
        
        -- Labels (label_list removed - use stg_pr_labels for detailed label info)
        pr.label_count,
        
        -- Metrics
        pr.comment_count,
        pr.time_to_first_comment_hours,
        pr.time_to_merge_hours,
        pr.time_to_close_without_merge_hours,
        
        -- Timestamps
        pr.created_at,
        pr.updated_at,
        pr.closed_at,
        pr.merged_at,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from pull_requests pr
    left join repositories r
        on pr.repository_full_name = r.repository_full_name
    left join users u
        on pr.author_id = u.user_id
    left join dates d_created
        on cast(pr.created_at as date) = d_created.date
    left join dates d_merged
        on cast(pr.merged_at as date) = d_merged.date
    left join dates d_closed
        on cast(pr.closed_at as date) = d_closed.date
)

select * from final
