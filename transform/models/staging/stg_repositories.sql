{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw_github', 'repositories') }}
),

renamed as (
    select
        -- Primary key
        id as repository_id,
        node_id as repository_node_id,
        
        -- Repository identification
        owner_login,
        owner_id,
        repo_name as repository_name,
        full_name as repository_full_name,
        
        -- Metadata
        description as repository_description,
        private as is_private,
        archived as is_archived,
        disabled as is_disabled,
        
        -- URLs
        html_url as repository_url,
        
        -- Timestamps
        created_at::timestamp as created_at,
        updated_at::timestamp as updated_at,
        pushed_at::timestamp as pushed_at,
        
        -- Statistics
        size as repository_size_kb,
        stargazers_count,
        watchers_count,
        forks_count,
        open_issues_count,
        
        -- Technical details
        language as primary_language,
        default_branch,
        license_name,
        
        -- Features
        has_issues,
        has_projects,
        has_wiki,
        has_pages,
        has_downloads,
        
        -- Topics (array)
        topics,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from source
)

select * from renamed
