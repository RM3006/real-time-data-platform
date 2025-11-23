{% macro validate_event_rules(event_type_col, product_id_col, user_id_col, products_cte, users_cte) %}
    /*
    Returns a boolean validation flag (true/false) based on business rules.
    Arguments:
        event_type_col: Column containing the event type (e.g., 'add_to_cart')
        product_id_col: Column containing the product ID
        user_id_col:    Column containing the user ID
        products_cte:   Name of the CTE/Table containing valid products
        users_cte:      Name of the CTE/Table containing valid users
    */
    case 
     
        -- Logic: Check Referential Integrity for Products (Orphans).
        -- If product_id exists, it must be found in the products catalog.
        when 
            {{ event_type_col }} not in ('page_view') 
            and (
                {{ product_id_col }} is null 
                or {{ product_id_col }} not in (select product_id from {{ products_cte }})
                )
        then false

        -- Logic: Check Referential Integrity for Users (Orphans).
        -- If user is not a 'guest', the ID must be found in the users database.
        when {{ user_id_col }} != 'guest'
             and {{ user_id_col }} not in (select user_id from {{ users_cte }}) then false
             
        -- Logic: Record passed all checks.
        else true
    end
{% endmacro %}