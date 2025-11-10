{{
    config(
        materialized='table'
    )
}}

with sessions as (
    select * from {{ ref('int_events_sessionized') }}
),

stg_users as (
    select * from {{ ref('users') }}
),

-- Aggregate all metrics for each session
session_metrics as (
    select
        session_id,
        user_id,
        min(event_at_ts) as session_started_at_ts,
        max(event_at_ts) as session_ended_at_ts,
        
        datediff(
            'second',
            session_started_at_ts,
            session_ended_at_ts
        ) as session_duration_seconds,
        
        count(distinct event_id) as total_events_in_session,
        
        count(distinct 
            case 
                when event_type = 'product_view' then product_id 
            end
        ) as distinct_products_viewed

    from sessions
    group by 1, 2
)

-- Join with user dimension to enrich the data
select
    m.session_id,
    m.user_id,
    u.country as user_country,
    m.session_started_at_ts,
    m.session_ended_at_ts,
    m.session_duration_seconds,
    m.total_events_in_session,
    m.distinct_products_viewed
from session_metrics as m
left join stg_users as u
    on m.user_id = u.user_id