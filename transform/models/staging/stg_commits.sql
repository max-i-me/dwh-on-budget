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
        _owner || '/' || _repo as repository_full_name,
        
        -- GitHub users (may be null if not linked to GitHub account)
        author__login as author_login,
        author__id as author_id,
        committer__login as committer_login,
        committer__id as committer_id,
        
        -- Git commit info
        commit__author__name as commit_author_name,
        commit__author__email as commit_author_email,
        commit__committer__name as committer_name,
        commit__committer__email as committer_email,
        
        -- Message
        commit__message as commit_message,
        length(commit__message) as message_length,
        
        -- References
        commit__tree__sha as tree_sha,
        
        -- Metrics
        commit__comment_count as comment_count,
        
        -- Timestamps
        commit__author__date::timestamp as commit_date,
        commit__committer__date::timestamp as committer_date,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from source
)

select * from renamed
