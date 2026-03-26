-- Staging model for GitHub PR reviews
-- Cleans and standardizes PR review data from raw layer

with source as (
    select * from {{ source('raw_github', 'pr_reviews') }}
),

cleaned as (
    select
        -- Primary key
        id as review_id,
        
        -- Foreign keys
        {{ dbt_utils.generate_surrogate_key(['_owner', '_repo']) }} as repository_key,
        _pr_number as pull_request_number,
        user.id as reviewer_user_id,
        
        -- Review metadata
        _owner as repository_owner,
        _repo as repository_name,
        state as review_state,  -- APPROVED, CHANGES_REQUESTED, COMMENTED, DISMISSED
        body as review_body,
        commit_id,
        
        -- Timestamps
        submitted_at::TIMESTAMP as submitted_at,
        
        -- Metadata
        _dlt_load_id,
        _dlt_id
        
    from source
    where user.id is not null  -- Filter out deleted users
)

select * from cleaned
