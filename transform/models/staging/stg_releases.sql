-- Staging model for GitHub releases
-- Cleans and standardizes release data from raw layer

with source as (
    select * from {{ source('raw_github', 'releases') }}
),

cleaned as (
    select
        -- Primary key
        id as release_id,
        
        -- Foreign keys
        {{ dbt_utils.generate_surrogate_key(['_owner', '_repo']) }} as repository_key,
        author.id as author_user_id,
        
        -- Release identifiers
        _owner as repository_owner,
        _repo as repository_name,
        tag_name,
        target_commitish,
        name as release_name,
        
        -- Release metadata
        draft as is_draft,
        prerelease as is_prerelease,
        body as release_notes,
        
        -- Timestamps
        created_at::TIMESTAMP as created_at,
        published_at::TIMESTAMP as published_at,
        
        -- Metadata
        _dlt_load_id,
        _dlt_id
        
    from source
)

select * from cleaned
