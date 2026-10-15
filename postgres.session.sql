-- Run this file to get an overview of both - staging and analytics schemas

select * from staging.customers limit 10;
select * from staging.sellers limit 10;
select * from staging.orders limit 10;
select * from staging.order_items limit 10;
select * from staging.order_reviews limit 10;
select * from staging.geolocation limit 10;
select * from staging.products limit 10;
select * from staging.order_payments limit 10;

select * from analytics.dim_customer limit 10;
select * from analytics.dim_seller limit 10;
select * from analytics.dim_order limit 10;
select * from analytics.fact_order_items limit 10;
select * from analytics.fact_reviews limit 10;
select * from analytics.geo_distribution limit 10;
select * from analytics.dim_product limit 10;
select * from analytics.fact_payments limit 10;
select * from analytics.dim_date limit 10;