{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw_github', 'repositories__topics') }}
),

renamed as (
    select
        -- Link to parent repository
        _dlt_parent_id as repository_dlt_id,
        _dlt_list_idx as topic_position,
        
        -- Topic value
        value as topic_name,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from source
)

select * from renamed
