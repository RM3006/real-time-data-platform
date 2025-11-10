{{
    config(
        materialized='view'
    )
}}

with stg_events as (
    select * from {{ ref('stg_events') }}
),

-- Step 1: Calculate the 'is_new_session' flag using LAG
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

    from stg_events
),

-- Step 2: Calculate the session index using SUM on the pre-calculated flag
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

-- Step 3: Create the final unique session ID
select
    event_id,
    event_type,
    user_id,
    product_id,
    platform,
    event_at_ts,
    user_id || '-' || to_char(session_index) as session_id
from events_with_session_index