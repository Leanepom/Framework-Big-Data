with source as (
    select * from {{ source('bronze', 'users') }}
),

typed as (
    select
        cast(uuid as uuid) as user_id,
        trim(username) as username,
        trim(name) as name,
        upper(trim(sex)) as sex,
        lower(trim(mail)) as email,
        cast(birthdate as date) as birthdate,
        -- The address spans 2 lines: the street, then the city, the state and the zip code
        split_part(address, chr(10), 1) as street,
        split_part(address, chr(10), 2) as address_line_2
    from source
),

first_orders as (
    select
        user_id,
        min(ordered_at::date) as first_order_date
    from {{ ref('stg_orders') }}
    group by user_id
)

select
    typed.user_id,
    typed.username,
    lower(trim(typed.username)) as username_normalized,
    typed.name,
    typed.sex,
    typed.email,

    case
        when first_orders.first_order_date is null
            or typed.birthdate <= first_orders.first_order_date
        then typed.birthdate
        else null
    end as birthdate,

    case
        when first_orders.first_order_date is null
            or typed.birthdate <= first_orders.first_order_date
        then true
        else false
    end as birthdate_is_valid,

    typed.street,

    -- Military addresses, such as "DPO AE 12345", have no comma
    nullif(
        regexp_extract(typed.address_line_2, '^(.+), [A-Z]{2} \d{5}$', 1),
        ''
    ) as city,

    regexp_extract(
        typed.address_line_2,
        '([A-Z]{2}) (\d{5})$',
        1
    ) as state,

    regexp_extract(
        typed.address_line_2,
        '([A-Z]{2}) (\d{5})$',
        2
    ) as zip_code

from typed
left join first_orders
    on typed.user_id = first_orders.user_id
