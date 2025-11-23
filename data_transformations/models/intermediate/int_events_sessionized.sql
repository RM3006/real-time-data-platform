{{
    config(
        materialized='view'
    )
}}

with stg_events as (
    select * from {{ ref('stg_events') }}
),

-- Step 1: Calculate the 'value' field using the product prices in products_snapshot
events_with_prices as (
    select
    e.*,
    coalesce(e.quantity * p.price,null) as value

    from stg_events e
    left join products_snapshot p
    ON  e.product_id = p.product_id
    AND e.event_at_ts >= p.dbt_valid_from
    AND e.event_at_ts <= coalesce(p.dbt_valid_to,'9999-12-31'::timestamp)
),

-- Step 2: Calculate the 'is_new_session' flag using LAG
events_with_new_session_flag as (
    select
        *,
        lag(event_at_ts) over (
            partition by user_id
            order by event_at_ts
        ) as previous_event_ts,
        
        datediff(
            'minute',
            previous_event_ts,
            event_at_ts
        ) as minutes_since_last_event,

        case 
            when minutes_since_last_event > 30 then 1
            when previous_event_ts is null then 1
            else 0
        end as is_new_session

    from events_with_prices
),

-- Step 3: Calculate the session index using SUM on the pre-calculated flag
events_with_session_index as (
    select
        *,
        sum(is_new_session) over (
            partition by user_id
            order by event_at_ts
            rows between unbounded preceding and current row
        ) as session_index
    from events_with_new_session_flag
)

-- Step 4: Create the final unique session ID and include new dimensions
select
    event_id,
    event_type,
    user_id,
    product_id,
    order_id,        
    value,           
    quantity,        
    platform,
    ip_address,      
    user_agent,      
    utm_source,      
    utm_medium,      
    utm_campaign,    
    event_at_ts,
    coalesce(user_id,'guest') || '-' || to_char(session_index) as session_id
from events_with_session_index