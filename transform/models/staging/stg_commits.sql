{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw_github', 'commits') }}
),

renamed as (
    select
        -- Primary key
        sha as commit_sha,
        node_id as commit_node_id,
        
        -- Repository
        repository_full_name,
        
        -- GitHub users (may be null if not linked to GitHub account)
        author_login,
        author_id,
        committer_login,
        committer_id,
        
        -- Git commit info
        commit_author_name,
        commit_author_email,
        committer_name,
        committer_email,
        
        -- Message
        message as commit_message,
        length(message) as message_length,
        
        -- References
        tree_sha,
        
        -- Metrics
        comment_count,
        
        -- Timestamps
        commit_date::timestamp as commit_date,
        committer_date::timestamp as committer_date,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from source
)

select * from renamed
