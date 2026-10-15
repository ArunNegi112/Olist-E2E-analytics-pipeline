insert into analytics.dim_customer 
    (
        customer_id, 
        customer_unique_id, 
        zip_prefix, city, 
        state, 
        latitude, 
        longitude
    )
select 
    C.customer_id,
    C.customer_unique_id,
    C.customer_zip_code_prefix,
    C.customer_city,
    C.customer_state,
    G.latitude,
    G.longitude
from staging.customers as C
left join staging.geolocation as G 
    on 
        C.customer_zip_code_prefix = G.zip_code
;
select * from analytics.dim_customer limit 10;




insert into analytics.dim_date (
    date_key, 
    "year", 
    quarter, 
    "month", 
    month_name, 
    day_of_week
)
select 
    d::DATE,
    EXTRACT(year from d)::INT,
    EXTRACT(quarter from d)::INT,
    EXTRACT(month from d)::INT,
    TRIM(TO_CHAR(d, 'Month')),
    TRIM(TO_CHAR(d, 'Day'))
from generate_series(
    '2016-09-01'::DATE,
    '2018-12-31'::DATE,
    '1 day'
) as d;
SELECT * FROM analytics.dim_date limit 10;




insert into analytics.dim_product (
    product_id,
    category_en,
    description_length,
    photos_qty,
    weight_g,
    volume_cubic_cm
)
select 
    product_id,
    CASE
        WHEN product_category_name IS NULL THEN 'UNKNOWN'
        ELSE product_category_name
    END,
    CASE 
        WHEN product_description_length IS NULL THEN 0
        ELSE product_description_length
    END,
    CASE 
        WHEN product_photos_qty IS NULL THEN 0
        ELSE product_photos_qty
    END,
    CASE 
        WHEN product_weight_g IS NULL THEN 0
        ELSE product_weight_g
    END,
    (product_length_cm * product_width_cm * product_height_cm) as volume
from staging.products;

SELECT * FROM analytics.dim_product LIMIT 10;
SELECT * FROM analytics.dim_product WHERE product_id='5eb564652db742ff8f28759cd8d2652a' LIMIT 10; 




insert into analytics.dim_seller (
    seller_id,
    zip_prefix,
    city,
    state,
    latitude,
    longitude
)
select 
    S.seller_id,
    S.seller_zip_code_prefix,
    S.seller_city,
    S.seller_state,
    G.latitude,
    G.longitude
from staging.sellers as S
left join staging.geolocation as G
    on 
        S.seller_zip_code_prefix = G.zip_code
;
select * from analytics.dim_seller limit 10;




insert into analytics.dim_order (
    order_id,
    customer_id,
    status,
    purchase_date,
    purchase_time,
    delivered_date,
    delivered_time,
    estimated_delivery,
    delivery_days,
    is_late
)
select 
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp::DATE,
    order_purchase_timestamp::TIME,
    order_delivered_customer_date::DATE,
    order_delivered_customer_date::TIME,
    order_estimated_delivery_date::DATE,
    (order_delivered_customer_date::DATE - order_purchase_timestamp::DATE)::INT,
    CASE 
        WHEN (order_estimated_delivery_date >= order_delivered_customer_date::DATE) THEN false
        WHEN (order_estimated_delivery_date < order_delivered_customer_date::DATE) THEN true
    END
from staging.orders as O;
select * from analytics.dim_order limit 10;



insert into analytics.fact_payments (
    order_id,
    payment_sequential,
    payment_type,
    installments,
    payment_value
)
select 
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
from staging.order_payments;

select * from analytics.fact_payments limit 10;



insert into analytics.fact_order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    price,
    freight_value
)
select 
    order_id,
    order_item_id,
    product_id,
    seller_id,
    price,
    freight_value
from staging.order_items;
select * from analytics.fact_order_items limit 10;



insert into analytics.fact_reviews (
    review_id,
    order_id,
    review_score,
    answer_timestamp
)
select 
    review_id,
    order_id,
    review_score,
    review_answer_timestamp
from staging.order_reviews;

select * from analytics.fact_reviews limit 10;




INSERT INTO analytics.geo_distribution (
    state,
    zip_prefix,
    state_lat,
    state_long,
    entity_id,
    entity_type
)
WITH state_coordinates AS (
    SELECT
        geo_state AS state,
        AVG(latitude) AS state_latitude,
        AVG(longitude) AS state_longitude
    FROM staging.geolocation
    GROUP BY geo_state
),

seller_data AS (
    SELECT
        s.seller_state AS state,
        s.seller_zip_code_prefix AS zip_prefix,
        sc.state_latitude AS state_lat,
        sc.state_longitude AS state_long,
        s.seller_id AS entity_id,
        'Seller' AS entity_type
    FROM staging.sellers AS s
    LEFT JOIN state_coordinates AS sc
        ON s.seller_state = sc.state
),

customer_data AS (
    SELECT DISTINCT ON (c.customer_unique_id)
        c.customer_state AS state,
        c.customer_zip_code_prefix AS zip_prefix,
        sc.state_latitude AS state_lat,
        sc.state_longitude AS state_long,
        c.customer_unique_id AS entity_id,
        'Customer' AS entity_type
    FROM staging.customers AS c
    LEFT JOIN state_coordinates AS sc
        ON c.customer_state = sc.state
    WHERE c.customer_unique_id IS NOT NULL
    ORDER BY c.customer_unique_id, c.customer_id
)

SELECT * FROM seller_data
UNION ALL
SELECT * FROM customer_data;


SELECT
    entity_type,
    COUNT(*) AS row_count,
    COUNT(DISTINCT entity_id) AS unique_entities
FROM analytics.geo_distribution
GROUP BY entity_type;

SELECT * FROM analytics.geo_distribution limit 10;