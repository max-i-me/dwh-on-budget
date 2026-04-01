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
        -- Extract issue number from issue_url (e.g., "https://api.github.com/repos/owner/repo/issues/123")
        cast(regexp_extract(issue_url, '\/issues\/(\d+)$', 1) as integer) as issue_number,
        _owner || '/' || _repo as repository_full_name,
        
        -- Content
        body as comment_body,
        length(body) as comment_length,
        
        -- Author
        user__login as author_login,
        user__id as author_id,
        
        -- Timestamps
        created_at::timestamp as created_at,
        updated_at::timestamp as updated_at,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from source
)

select * from renamed
