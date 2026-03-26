{{
    config(
        materialized='view'
    )
}}

-- Calculate issue lifecycle metrics
with issues as (
    select * from {{ ref('stg_issues') }}
),

comments as (
    select
        repository_full_name,
        issue_number,
        count(*) as comment_count,
        min(created_at) as first_comment_at
    from {{ ref('stg_issue_comments') }}
    group by repository_full_name, issue_number
),

enriched as (
    select
        i.issue_id,
        i.issue_number,
        i.repository_full_name,
        i.issue_title,
        i.issue_state,
        i.author_login,
        i.author_id,
        i.label_list,
        i.created_at,
        i.updated_at,
        i.closed_at,
        
        -- Comment metrics
        coalesce(c.comment_count, 0) as comment_count,
        c.first_comment_at,
        
        -- Lifecycle metrics
        case 
            when i.closed_at is not null then
                datediff('hour', i.created_at, i.closed_at)
            else null
        end as time_to_close_hours,
        
        case 
            when c.first_comment_at is not null then
                datediff('hour', i.created_at, c.first_comment_at)
            else null
        end as time_to_first_response_hours,
        
        -- Status flags
        case when i.closed_at is not null then true else false end as is_closed,
        case when i.assignee_id is not null then true else false end as is_assigned,
        
        -- Label analysis
        array_length(i.label_list) as label_count,
        case 
            when array_contains(i.label_list, 'bug') then true 
            else false 
        end as is_bug,
        case 
            when array_contains(i.label_list, 'enhancement') 
                or array_contains(i.label_list, 'feature') then true 
            else false 
        end as is_enhancement
        
    from issues i
    left join comments c
        on i.repository_full_name = c.repository_full_name
        and i.issue_number = c.issue_number
)

select * from enriched
