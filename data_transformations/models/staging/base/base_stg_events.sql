{{ config(materialized='ephemeral') }}

with source as (
    -- Import raw JSON data from the Snowflake source table
    select * from {{ source('realtime_platform', 'RAW_REALTIME_DATA_EVENTS') }}
),

products as (
    -- Import product IDs for referential integrity checks
    select product_id from {{ ref('products') }}
),

users as (
    -- Import user IDs for referential integrity checks
    select user_id from {{ ref('users') }}
),

parsed as (
    select
        -- Extraction: Pull fields from the JSON VARIANT column and cast to specific types
        raw_data:event_id::string as event_id,
        
        -- Logic: Replace NULL user IDs with 'guest' to prevent null-pointer issues downstream
        coalesce(raw_data:user_id::string, 'guest') as user_id,
        
        raw_data:product_id::string as product_id,
        raw_data:order_id::string as order_id,

        -- Normalization: Force event types to lowercase to handle inconsistent casing (e.g., 'Checkout' -> 'checkout')
        lower(raw_data:event_type::string) as event_type,
        
        -- Logic: handle hybrid timestamp formats (ISO string vs. Unix integer)
        -- iff(
        --     is_varchar(raw_data:event_timestamp),
        --     try_to_timestamp_ntz(raw_data:event_timestamp::string), -- Cast to STRING
        --     to_timestamp_ntz(raw_data:event_timestamp::int)         -- Cast to INT
        -- ) as event_at_ts,

        raw_data:event_timestamp::timestamp_ntz as event_at_ts,
        
        -- Extraction: Additional facts and dimensions
        raw_data:quantity::int as quantity,
        raw_data:platform::string as platform,
        raw_data:ip_address::string as ip_address,
        raw_data:user_agent::string as user_agent,
        raw_data:utm_source::string as utm_source,
        raw_data:utm_medium::string as utm_medium,
        raw_data:utm_campaign::string as utm_campaign,

        metadata_filename,
        loaded_at

    from source
    where raw_data:event_id is not null
    and raw_data:event_timestamp::timestamp_ntz >= '2025-11-23 15:20:00.000'
),

validated as (
    select
    *,
    {{
        validate_event_rules(
            event_type_col='event_type',
            product_id_col='product_id',
            products_cte='products',
            user_id_col='user_id',
            users_cte='users'
        )
    }} as is_valid_record

    from parsed
)

select * from validated