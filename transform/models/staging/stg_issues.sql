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
        
        -- Issue identification
        number as issue_number,
        repository_full_name,
        
        -- Content
        title as issue_title,
        body as issue_body,
        
        -- Status
        state as issue_state,
        locked as is_locked,
        
        -- People
        user_login as author_login,
        user_id as author_id,
        assignee_login,
        assignee_id,
        
        -- Labels (array)
        labels as label_list,
        
        -- Metrics
        comments_count,
        
        -- Timestamps
        created_at::timestamp as created_at,
        updated_at::timestamp as updated_at,
        closed_at::timestamp as closed_at,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from source
)

select * from renamed
