{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw_github', 'pull_requests') }}
),

renamed as (
    select
        -- Primary key
        id as pull_request_id,
        node_id as pull_request_node_id,
        
        -- PR identification
        number as pr_number,
        repository_full_name,
        
        -- Content
        title as pr_title,
        body as pr_body,
        
        -- Status
        state as pr_state,
        locked as is_locked,
        draft as is_draft,
        
        -- People
        user_login as author_login,
        user_id as author_id,
        assignee_login,
        assignee_id,
        
        -- Labels (array)
        labels as label_list,
        
        -- Git references
        head_ref,
        head_sha,
        base_ref,
        base_sha,
        merge_commit_sha,
        
        -- Merge status
        case 
            when merged_at is not null then true 
            else false 
        end as is_merged,
        
        -- Timestamps
        created_at::timestamp as created_at,
        updated_at::timestamp as updated_at,
        closed_at::timestamp as closed_at,
        merged_at::timestamp as merged_at,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from source
)

select * from renamed
