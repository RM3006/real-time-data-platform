with base_events as (
    -- Logic: Inherit all parsing and validation rules from the ephemeral model
    select * from {{ ref('base_stg_events') }}
),

deduplicated as (
    select
        *,
        -- Logic: Identify duplicate event_ids. 
        -- Partition by ID and sort by ingestion time to prioritize the most recent version.
        row_number() over(
            partition by event_id 
            order by loaded_at desc
        ) as duplicate_rank
    from base_events
    
    -- Critical Filter: Only allow records that passed the validation logic in the base model
    where is_valid_record = true
)

-- Logic: Select only the most recent version of each event (rank 1) and drop helper columns
select * exclude (duplicate_rank, is_valid_record)
from deduplicated
where duplicate_rank = 1