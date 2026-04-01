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
        _dlt_id as pr_dlt_id,  -- For joining with child tables
        
        -- PR identification
        number as pr_number,
        _owner as repository_owner,
        _repo as repository_name,
        _owner || '/' || _repo as repository_full_name,
        
        -- Content
        title as pr_title,
        body as pr_body,
        
        -- Status
        state as pr_state,
        locked as is_locked,
        draft as is_draft,
        
        -- People
        user__login as author_login,
        user__id as author_id,
        assignee__login as assignee_login,
        assignee__id as assignee_id,
        
        -- Labels moved to separate staging model (stg_pr_labels)
        
        -- Git references
        head__ref as head_ref,
        head__sha as head_sha,
        base__ref as base_ref,
        base__sha as base_sha,
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
