{{ config(materialized='table') }}

with base_events as (
    -- Logic: Inherit all parsing and validation rules from the ephemeral model
    select * from {{ ref('base_stg_events') }}
)

select * from base_events
-- Critical Filter: Capture ONLY the records that failed validation
where is_valid_record = false

