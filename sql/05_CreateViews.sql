-- create view to get limit of dates present in data
CREATE VIEW staging.date_limits AS
WITH orders_date_limit AS (
    SELECT 
        MIN(order_purchase_timestamp) AS min_date,
        MAX(order_estimated_delivery_date) AS max_date
    FROM staging.orders
),
reviews_date_limit AS (
    SELECT 
        MAX(review_answer_timestamp) AS max_date
    FROM staging.order_reviews
)
SELECT 
    orders_date_limit.min_date::DATE AS min_date,
    GREATEST(
        orders_date_limit.max_date::DATE,
        reviews_date_limit.max_date::DATE
    ) AS max_date
FROM orders_date_limit
CROSS JOIN reviews_date_limit;
-- Check the overall limits of date in staging data
SELECT * FROM staging.date_limits;