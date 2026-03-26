{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw_github', 'stargazers') }}
),

renamed as (
    select
        -- Keys
        user_id,
        user_login,
        repository_full_name,
        
        -- Timestamp
        starred_at::timestamp as starred_at,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from source
)

select * from renamed
