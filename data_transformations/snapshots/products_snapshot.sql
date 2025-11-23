{% snapshot products_snapshot %}

{{ config(
    target_database ='REALTIME_DATA_PLATFORM_DB',
    target_schema = 'ANALYTICS',
    unique_key ='product_id',
    strategy ='check',
    check_cols=['category','product_name','price'],
    pre_hook="ALTER SESSION SET TIMEZONE = 'Europe/Paris';"
    )
}}

select * from {{ ref('products')}}

{% endsnapshot %}
