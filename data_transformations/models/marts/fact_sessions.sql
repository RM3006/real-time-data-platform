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

        sum(case when event_type ='checkout' then value else 0 end) as total_session_revenue,
        sum(case when event_type ='add_to_cart' then 1 else 0 end) as total_items_added_to_cart,
        
        count(distinct 
            case 
                when event_type = 'product_view' then product_id 
            end
        ) as distinct_products_viewed,

        max(utm_source) as session_utm_source

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
    m.total_session_revenue,
    m.total_items_added_to_cart,
    m.session_utm_source
from session_metrics as m
left join stg_users as u
    on m.user_id = u.user_id