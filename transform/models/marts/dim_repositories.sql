{{
    config(
        materialized='table'
    )
}}

with repositories as (
    select * from {{ ref('stg_repositories') }}
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['repository_id']) }} as repo_key,
        
        -- Natural key
        repository_id,
        repository_full_name,
        
        -- Repository attributes
        repository_name,
        owner_login,
        owner_id,
        repository_description,
        repository_url,
        
        -- Technical details
        primary_language,
        default_branch,
        license_name,
        topics,
        
        -- Statistics (snapshot at load time)
        stargazers_count,
        watchers_count,
        forks_count,
        open_issues_count,
        repository_size_kb,
        
        -- Features
        has_issues,
        has_projects,
        has_wiki,
        has_pages,
        has_downloads,
        
        -- Status flags
        is_private,
        is_archived,
        is_disabled,
        
        -- Timestamps
        created_at,
        updated_at,
        pushed_at,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from repositories
)

select * from final
