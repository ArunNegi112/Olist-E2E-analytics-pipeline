COPY staging.geolocation 
FROM 'C:\Users\Arun\Documents\Documents\Brazillian_Ecom_Sql_Project\data\transformed_data\olist_geolocation_dataset_cleaned.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',',ENCODING 'UTF8');

COPY staging.customers 
FROM 'C:\Users\Arun\Documents\Documents\Brazillian_Ecom_Sql_Project\data\original_data\olist_customers_dataset.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',',ENCODING 'UTF8');

COPY staging.products 
FROM 'C:\Users\Arun\Documents\Documents\Brazillian_Ecom_Sql_Project\data\transformed_data\olist_products_dataset_transformed.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',',ENCODING 'UTF8');

COPY staging.sellers 
FROM 'C:\Users\Arun\Documents\Documents\Brazillian_Ecom_Sql_Project\data\original_data\olist_sellers_dataset.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',',ENCODING 'UTF8');

COPY staging.orders 
FROM 'C:\Users\Arun\Documents\Documents\Brazillian_Ecom_Sql_Project\data\original_data\olist_orders_dataset.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',',ENCODING 'UTF8');

COPY staging.order_items 
FROM 'C:\Users\Arun\Documents\Documents\Brazillian_Ecom_Sql_Project\data\original_data\olist_order_items_dataset.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',',ENCODING 'UTF8');

COPY staging.order_payments 
FROM 'C:\Users\Arun\Documents\Documents\Brazillian_Ecom_Sql_Project\data\original_data\olist_order_payments_dataset.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',',ENCODING 'UTF8');

COPY staging.order_reviews 
FROM 'C:\Users\Arun\Documents\Documents\Brazillian_Ecom_Sql_Project\data\original_data\olist_order_reviews_dataset.csv'
WITH (FORMAT csv, HEADER true, DELIMITER ',',ENCODING 'UTF8');
