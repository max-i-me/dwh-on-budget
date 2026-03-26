{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw_github', 'issue_comments') }}
),

renamed as (
    select
        -- Primary key
        id as comment_id,
        node_id as comment_node_id,
        
        -- Comment association
        issue_number,
        repository_full_name,
        
        -- Content
        body as comment_body,
        length(body) as comment_length,
        
        -- Author
        user_login as author_login,
        user_id as author_id,
        
        -- Timestamps
        created_at::timestamp as created_at,
        updated_at::timestamp as updated_at,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from source
)

select * from renamed
