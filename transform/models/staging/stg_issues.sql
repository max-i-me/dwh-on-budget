{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw_github', 'issues') }}
),

renamed as (
    select
        -- Primary key
        id as issue_id,
        node_id as issue_node_id,
        _dlt_id as issue_dlt_id,  -- For joining with child tables
        
        -- Issue identification
        number as issue_number,
        _owner || '/' || _repo as repository_full_name,
        
        -- Content
        title as issue_title,
        body as issue_body,
        
        -- Status
        state as issue_state,
        locked as is_locked,
        
        -- People
        user__login as author_login,
        user__id as author_id,
        assignee__login as assignee_login,
        assignee__id as assignee_id,
        
        -- Labels moved to separate staging model (stg_issue_labels)
        
        -- Metrics
        comments as comments_count,
        
        -- Timestamps
        created_at::timestamp as created_at,
        updated_at::timestamp as updated_at,
        closed_at::timestamp as closed_at,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from source
)

select * from renamed
