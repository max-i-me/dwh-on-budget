{{
    config(
        materialized='view'
    )
}}

-- Enrich pull requests with review and comment data
with pull_requests as (
    select * from {{ ref('stg_pull_requests') }}
),

pr_labels as (
    select
        pr_dlt_id,
        count(*) as label_count
    from {{ ref('stg_pr_labels') }}
    group by pr_dlt_id
),

-- NOTE: PR reviews are disabled in extraction to avoid rate limits
-- This CTE returns empty set but maintains schema compatibility
reviews as (
    select
        cast(null as varchar) as repository_owner,
        cast(null as varchar) as repository_name,
        cast(null as bigint) as pull_request_number,
        cast(0 as bigint) as review_count,
        cast(0 as bigint) as unique_reviewers,
        cast(null as timestamp) as first_review_at,
        cast(null as timestamp) as last_review_at,
        cast(0 as bigint) as approval_count,
        cast(0 as bigint) as changes_requested_count,
        cast(0 as bigint) as comment_review_count
    where 1=0  -- Empty result set
),

comments as (
    select
        repository_full_name,
        issue_number as pr_number,
        count(*) as comment_count,
        min(created_at) as first_comment_at
    from {{ ref('stg_issue_comments') }}
    group by repository_full_name, issue_number
),

enriched as (
    select
        pr.pull_request_id,
        pr.pr_number,
        pr.repository_full_name,
        pr.pr_title,
        pr.pr_state,
        pr.is_merged,
        pr.is_draft,
        pr.author_login,
        pr.author_id,
        pr.created_at,
        pr.updated_at,
        pr.closed_at,
        pr.merged_at,
        
        -- Review metrics
        coalesce(r.review_count, 0) as review_count,
        coalesce(r.unique_reviewers, 0) as unique_reviewers,
        r.first_review_at,
        r.last_review_at,
        coalesce(r.approval_count, 0) as approval_count,
        coalesce(r.changes_requested_count, 0) as changes_requested_count,
        coalesce(r.comment_review_count, 0) as comment_review_count,
        
        -- Comment metrics
        coalesce(c.comment_count, 0) as comment_count,
        c.first_comment_at,
        
        -- Lifecycle metrics
        case 
            when r.first_review_at is not null then
                datediff('hour', pr.created_at, r.first_review_at)
            else null
        end as time_to_first_review_hours,
        
        case 
            when c.first_comment_at is not null then
                datediff('hour', pr.created_at, c.first_comment_at)
            else null
        end as time_to_first_comment_hours,
        
        case 
            when pr.merged_at is not null then
                datediff('hour', pr.created_at, pr.merged_at)
            else null
        end as time_to_merge_hours,
        
        case 
            when pr.closed_at is not null and pr.merged_at is null then
                datediff('hour', pr.created_at, pr.closed_at)
            else null
        end as time_to_close_without_merge_hours,
        
        -- Status flags
        case when pr.closed_at is not null then true else false end as is_closed,
        case 
            when pr.closed_at is not null and pr.merged_at is null then true 
            else false 
        end as is_closed_without_merge,
        
        -- Label analysis (from separate label table)
        coalesce(l.label_count, 0) as label_count
        
    from pull_requests pr
    left join reviews r
        on pr.repository_owner = r.repository_owner
        and pr.repository_name = r.repository_name
        and pr.pr_number = r.pull_request_number
    left join comments c
        on pr.repository_full_name = c.repository_full_name
        and pr.pr_number = c.pr_number
    left join pr_labels l
        on pr.pr_dlt_id = l.pr_dlt_id
)

select * from enriched
