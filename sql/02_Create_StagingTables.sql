/*
CONTEXT
This dataset was generously provided by Olist, the largest department store in Brazilian marketplaces. Olist connects small businesses from all over Brazil to channels without hassle and with a single contract. Those merchants are able to sell their products through the Olist Store and ship them directly to the customers using Olist logistics partners. See more on our website: www.olist.com

After a customer purchases the product from Olist Store a seller gets notified to fulfill that order. Once the customer receives the product, or the estimated delivery date is due, the customer gets a satisfaction survey by email where he can give a note for the purchase experience and write down some comments.

Attention
An order might have multiple items.
Each item might be fulfilled by a distinct seller.
All text identifying stores and partners where replaced by the names of Game of Thrones great houses.
*/


CREATE TABLE staging.geolocation
(
    zip_code VARCHAR(5) PRIMARY KEY,  
    latitude NUMERIC,
    longitude NUMERIC,
    city VARCHAR,
    geo_state VARCHAR
);


CREATE TABLE staging.customers
(
    customer_id VARCHAR(32) PRIMARY KEY,
    customer_unique_id VARCHAR(32),
    customer_zip_code_prefix VARCHAR(5),
    customer_city TEXT,
    customer_state TEXT,

    FOREIGN KEY (customer_zip_code_prefix)
        REFERENCES staging.geolocation(zip_code)
);


CREATE TABLE staging.products
(
    product_id VARCHAR(32) PRIMARY KEY,
    product_category_name VARCHAR,
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g NUMERIC,
    product_length_cm NUMERIC,
    product_height_cm NUMERIC,
    product_width_cm NUMERIC
);


CREATE TABLE staging.sellers
(   
    seller_id VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5),
    seller_city VARCHAR,
    seller_state VARCHAR,

    FOREIGN KEY (seller_zip_code_prefix)
        REFERENCES staging.geolocation(zip_code)
);


CREATE TABLE staging.orders
(
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32),
    order_status VARCHAR(32),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date DATE,

    FOREIGN KEY (customer_id)
        REFERENCES staging.customers(customer_id)
);

CREATE TABLE staging.order_items
(
    order_id VARCHAR(32),
    order_item_id INT,
    product_id VARCHAR(32),
    seller_id VARCHAR(32),
    shipping_limit_date TIMESTAMP,
    price NUMERIC,
    freight_value NUMERIC,

    PRIMARY KEY (order_id, order_item_id),

    FOREIGN KEY (product_id)
        REFERENCES staging.products(product_id),
    
    FOREIGN KEY (order_id)
        REFERENCES staging.orders(order_id),

    FOREIGN KEY (seller_id)
        REFERENCES staging.sellers(seller_id)
);


CREATE TABLE staging.order_payments
(
    order_id VARCHAR(32),
    payment_sequential INT, 
    payment_type VARCHAR,
    payment_installments INT,
    payment_value NUMERIC,

    PRIMARY KEY (order_id, payment_sequential),

    FOREIGN KEY (order_id)
        REFERENCES staging.orders(order_id)
);


CREATE TABLE staging.order_reviews
(
    review_id VARCHAR(32),
    order_id VARCHAR(32),
    review_score INT,

    CONSTRAINT valid_score
        CHECK (review_score IN (1,2,3,4,5)),

    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATE,
    review_answer_timestamp TIMESTAMP,

    PRIMARY KEY (order_id, review_id),

    FOREIGN KEY (order_id)
        REFERENCES staging.orders(order_id)
);