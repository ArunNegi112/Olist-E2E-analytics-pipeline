CREATE TABLE analytics.dim_customer
(
    customer_id VARCHAR(32) PRIMARY KEY,
    customer_unique_id VARCHAR(32),
    zip_prefix VARCHAR(5),
    city TEXT,
    state TEXT,
    latitude NUMERIC,
    longitude NUMERIC
);




CREATE TABLE analytics.dim_date
(
    date_key DATE PRIMARY KEY,
    "year" INT NOT NULL,
    quarter INT NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    "month" INT NOT NULL CHECK (month BETWEEN 1 AND 12),
    month_name VARCHAR(20) NOT NULL,
    day_of_week VARCHAR(20) NOT NULL
);




CREATE TABLE analytics.dim_product
(
    product_id VARCHAR(32) PRIMARY KEY,
    category_en VARCHAR,
    description_length INT,
    photos_qty INT,
    weight_g NUMERIC,
    volume_cubic_cm NUMERIC
);




CREATE TABLE analytics.dim_seller
(
    seller_id VARCHAR(32) PRIMARY KEY,
    zip_prefix VARCHAR(5),
    city VARCHAR,
    state VARCHAR,
    latitude NUMERIC,
    longitude NUMERIC
);




CREATE TABLE analytics.dim_order
(
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    status VARCHAR(32),
    purchase_date DATE,
    purchase_time TIME,
    delivered_date DATE,
    delivered_time TIME,
    estimated_delivery DATE,
    delivery_days INT,
    is_late BOOLEAN,

    FOREIGN KEY (customer_id)
        REFERENCES analytics.dim_customer(customer_id),

    FOREIGN KEY (purchase_date)
        REFERENCES analytics.dim_date(date_key)
);




CREATE TABLE analytics.fact_payments
(
    order_id VARCHAR(32),
    payment_sequential INT,
    payment_type VARCHAR,
    installments INT,
    payment_value NUMERIC,

    PRIMARY KEY (order_id, payment_sequential),

    FOREIGN KEY (order_id)
        REFERENCES analytics.dim_order(order_id)
);




CREATE TABLE analytics.fact_order_items
(
    order_id VARCHAR(32),
    order_item_id INT,
    product_id VARCHAR(32) NOT NULL,
    seller_id VARCHAR(32) NOT NULL,
    price NUMERIC,
    freight_value NUMERIC,

    PRIMARY KEY (order_id, order_item_id),

    FOREIGN KEY (order_id)
        REFERENCES analytics.dim_order(order_id),

    FOREIGN KEY (product_id)
        REFERENCES analytics.dim_product(product_id),

    FOREIGN KEY (seller_id)
        REFERENCES analytics.dim_seller(seller_id)
);




CREATE TABLE analytics.fact_reviews
(
    review_id VARCHAR(32),
    order_id VARCHAR(32),
    review_score INT CHECK (review_score IN (1, 2, 3, 4, 5)),
    answer_timestamp TIMESTAMP,

    PRIMARY KEY (review_id, order_id),

    FOREIGN KEY (order_id)
        REFERENCES analytics.dim_order(order_id)
);



CREATE TABLE analytics.geo_distribution
(
    state TEXT,
    zip_prefix VARCHAR(5),
    state_lat NUMERIC,
    state_long NUMERIC,
    entity_id VARCHAR(32),
    entity_type TEXT CHECK (entity_type IN ('Customer', 'Seller')),

    PRIMARY KEY (entity_id, entity_type)
);

