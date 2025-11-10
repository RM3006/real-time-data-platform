with source as (

    select * from  {{source('realtime_platform','RAW_REALTIME_DATA_EVENTS')}}
),

renamed_and_typed as (

    select
        -- Parse the VARIANT data using the ':' operator
        -- and cast it to the correct type using '::'

        raw_data:event_id::string as event_id,
        raw_data:event_type::string as event_type,
        raw_data:user_id::string as user_id,
        raw_data:product_id::string as product_id,
        
        -- Convert the ISO timestamp string to a Snowflake timestamp
        raw_data:event_timestamp::timestamp_ntz as event_at_ts,
        
        raw_data:platform::string as platform,
        
        -- Bring in our metadata columns
        metadata_filename,
        metadata_file_row_number,
        loaded_at

    from source

    -- Basic data quality filter
    where raw_data:event_id is not null

),

deduplicated as (
    select
        *,
        -- Assign a row number to each group of duplicate event_ids,
        -- ordering by the ingestion timestamp to get the latest one.
        row_number() over(
            partition by event_id 
            order by loaded_at desc
        ) as duplicate_rank
    from renamed_and_typed
)

-- Select only the latest record for each event_id
select * from deduplicated where duplicate_rank = 1