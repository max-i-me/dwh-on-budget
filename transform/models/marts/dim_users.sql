{{
    config(
        materialized='table'
    )
}}

with users as (
    select * from {{ ref('stg_users') }}
),

final as (
    select
        -- Surrogate key
        {{ dbt_utils.generate_surrogate_key(['user_id']) }} as user_key,
        
        -- Natural key
        user_id,
        user_login,
        
        -- Attributes
        is_bot,
        
        -- Metadata
        current_timestamp as _loaded_at
        
    from users
)

select * from final
