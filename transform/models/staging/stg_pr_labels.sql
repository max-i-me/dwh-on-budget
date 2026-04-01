{{
    config(
        materialized='view'
    )
}}

with source as (
    select * from {{ source('raw_github', 'pull_requests__labels') }}
),

renamed as (
    select
        -- Link to parent pull request
        _dlt_parent_id as pr_dlt_id,
        _dlt_list_idx as label_position,
        
        -- Label details
        id as label_id,
        name as label_name,
        color as label_color,
        description as label_description,
        "default" as is_default_label,  -- "default" is a reserved keyword
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from source
)

select * from renamed
