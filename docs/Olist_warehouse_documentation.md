# Olist Warehouse Documentation: `staging` and `analytics` Schemas

This document describes every table and column in the PostgreSQL database `OlistCustomerDB`.

The database has two layers:

| Schema | Purpose | Built from |
|---|---|---|
| `staging` | A clean, relational copy of the source data with primary keys, foreign keys and constraints. Minimal changes from the CSVs. | CSV files (`03_InsertData.sql`) |
| `analytics` | A dimensional model (dimension and fact tables) designed for reporting in Power BI. Adds derived columns and drops columns that reporting does not need. | `staging` tables (`06_InsertData.sql`) |

**Load order:** CSVs → `staging` → `analytics`.

---

## Part 1: Staging Schema

### Overview

| Table | Rows | Source file | Primary key |
|---|---:|---|---|
| `staging.geolocation` | 19,177 | `olist_geolocation_dataset_cleaned.csv` (transformed) | `zip_code` |
| `staging.customers` | 99,441 | `olist_customers_dataset.csv` | `customer_id` |
| `staging.products` | 32,951 | `olist_products_dataset_transformed.csv` (transformed) | `product_id` |
| `staging.sellers` | 3,095 | `olist_sellers_dataset.csv` | `seller_id` |
| `staging.orders` | 99,441 | `olist_orders_dataset.csv` | `order_id` |
| `staging.order_items` | 112,650 | `olist_order_items_dataset.csv` | `(order_id, order_item_id)` |
| `staging.order_payments` | 103,886 | `olist_order_payments_dataset.csv` | `(order_id, payment_sequential)` |
| `staging.order_reviews` | 99,224 | `olist_order_reviews_dataset.csv` | `(order_id, review_id)` |

The `product_category_name_translation.csv` file is **not** loaded as a table. The translation is applied in Python (`01_Data_Cleaning.ipynb`) before products are loaded.

### Staging relationships

| Child table | Foreign key column | Parent table | Parent column |
|---|---|---|---|
| `customers` | `customer_zip_code_prefix` | `geolocation` | `zip_code` |
| `sellers` | `seller_zip_code_prefix` | `geolocation` | `zip_code` |
| `orders` | `customer_id` | `customers` | `customer_id` |
| `order_items` | `order_id` | `orders` | `order_id` |
| `order_items` | `product_id` | `products` | `product_id` |
| `order_items` | `seller_id` | `sellers` | `seller_id` |
| `order_payments` | `order_id` | `orders` | `order_id` |
| `order_reviews` | `order_id` | `orders` | `order_id` |

Parent tables are created and loaded first, in this order: `geolocation` → `customers`, `products`, `sellers` → `orders` → `order_items`, `order_payments`, `order_reviews`.

---

### 1. `staging.geolocation`
Spatial reference table mapping each postal-code prefix to one set of coordinates. It is cleaned so that each prefix appears exactly once, which allows it to be the target of the foreign keys in `customers` and `sellers`.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `zip_code` | VARCHAR(5) | **PK** | The first 5 digits of the postal code, stored as text to keep leading zeros (e.g., `01046`). Source column: `geolocation_zip_code_prefix`. |
| `latitude` | NUMERIC | Nullable | The **mean** latitude of all source records for this zip code. `NULL` for the 162 zip codes that were missing from the source. |
| `longitude` | NUMERIC | Nullable | The **mean** longitude of all source records for this zip code. `NULL` for the 162 patched zip codes. |
| `city` | VARCHAR | Nullable | The **first** city name found for this zip code in the source. `NULL` for the patched zip codes. |
| `geo_state` | VARCHAR | Nullable | The **first** state abbreviation found for this zip code in the source (e.g., SP, RJ). `NULL` for the patched zip codes. |

**Cleaning applied before loading**
- The source had about 1,000,163 rows for 19,015 distinct prefixes. It was collapsed to one row per prefix.
- 162 zip codes used by customers or sellers but absent from the source were appended with all other fields `NULL`, so the foreign keys stay valid.

---

### 2. `staging.customers`
Customer records, one row per order-level customer ID.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `customer_id` | VARCHAR(32) | **PK** | Unique key generated **per order**. A returning customer gets a new `customer_id` on each purchase. Joins to `orders`. |
| `customer_unique_id` | VARCHAR(32) | Nullable | The **permanent identifier** of the real customer. Use this, not `customer_id`, to count customers or track repeat purchases. |
| `customer_zip_code_prefix` | VARCHAR(5) | **FK** → `geolocation.zip_code` | First 5 digits of the customer's postal code. |
| `customer_city` | TEXT | Nullable | City where the customer is located. |
| `customer_state` | TEXT | Nullable | Brazilian state abbreviation (e.g., SP, RJ). |

---

### 3. `staging.products`
Product catalog with category and physical attributes. Loaded from the **transformed** CSV, so category names are already in English.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `product_id` | VARCHAR(32) | **PK** | Unique identifier of the product. |
| `product_category_name` | VARCHAR | Nullable | Product category in **English**, translated in Python. If no translation existed, the original Portuguese name is kept. `NULL` for products with no category. |
| `product_name_length` | INT | Nullable | Character count of the product title. The source column is spelled `product_name_lenght`; the staging column uses the corrected spelling. |
| `product_description_length` | INT | Nullable | Character count of the product description (source spelling: `product_description_lenght`). |
| `product_photos_qty` | INT | Nullable | Number of photos on the product page. |
| `product_weight_g` | NUMERIC | Nullable | Product weight in grams. |
| `product_length_cm` | NUMERIC | Nullable | Package length in centimeters. |
| `product_height_cm` | NUMERIC | Nullable | Package height in centimeters. |
| `product_width_cm` | NUMERIC | Nullable | Package width in centimeters. |

**Data quality notes**
- 610 products have no category or name, description and photo metadata. 2 products have missing physical dimensions. These rows are kept because order items reference them.

---

### 4. `staging.sellers`
Master list of marketplace sellers.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `seller_id` | VARCHAR(32) | **PK** | Unique identifier of the seller. |
| `seller_zip_code_prefix` | VARCHAR(5) | **FK** → `geolocation.zip_code` | First 5 digits of the seller's postal code. |
| `seller_city` | VARCHAR | Nullable | City where the seller is registered. |
| `seller_state` | VARCHAR | Nullable | Brazilian state abbreviation. |

---

### 5. `staging.orders`
One row per order, with the status and the key timestamps of its lifecycle.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `order_id` | VARCHAR(32) | **PK** | Unique identifier of the order. |
| `customer_id` | VARCHAR(32) | **FK** → `customers.customer_id` | The order-level customer ID. |
| `order_status` | VARCHAR(32) | Nullable | Current stage of the order: `delivered`, `shipped`, `invoiced`, `processing`, `created`, `approved`, `canceled` or `unavailable`. |
| `order_purchase_timestamp` | TIMESTAMP | Nullable | When the customer completed checkout. |
| `order_approved_at` | TIMESTAMP | Nullable | When payment was approved. `NULL` for some canceled or newly created orders. |
| `order_delivered_carrier_date` | TIMESTAMP | Nullable | When the seller handed the parcel to the carrier. `NULL` if not yet shipped. |
| `order_delivered_customer_date` | TIMESTAMP | Nullable | When the customer actually received the parcel. `NULL` for orders not delivered. |
| `order_estimated_delivery_date` | DATE | Nullable | The delivery date promised at checkout. Stored as a **date** (the time portion of the source is dropped). |

**Data quality notes**
- Missing timestamps are explained mostly by order status (canceled, unavailable, invoiced, processing, shipped) and are kept as `NULL`.
- Only a few `delivered` orders have a missing timestamp, which are likely genuine data gaps.

---

### 6. `staging.order_items`
One row per item inside an order, with price and freight.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `order_id` | VARCHAR(32) | **PK (part)**, **FK** → `orders.order_id` | The order this item belongs to. |
| `order_item_id` | INT | **PK (part)** | Sequence number of the item inside the order (1, 2, 3, ...). Together with `order_id` it identifies one line. |
| `product_id` | VARCHAR(32) | **FK** → `products.product_id` | The product sold. |
| `seller_id` | VARCHAR(32) | **FK** → `sellers.seller_id` | The seller fulfilling this item. Different items in one order can have different sellers. |
| `shipping_limit_date` | TIMESTAMP | Nullable | Deadline for the seller to hand the item to the carrier. |
| `price` | NUMERIC | Nullable | Selling price of the item, excluding freight. |
| `freight_value` | NUMERIC | Nullable | Shipping fee charged for the item. |

---

### 7. `staging.order_payments`
One row per payment made for an order. An order paid with several methods has several rows.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `order_id` | VARCHAR(32) | **PK (part)**, **FK** → `orders.order_id` | The order being paid. |
| `payment_sequential` | INT | **PK (part)** | Sequence number of the payment within the order (1, 2, ...). |
| `payment_type` | VARCHAR | Nullable | Payment method: `credit_card`, `boleto`, `voucher`, `debit_card` or `not_defined`. |
| `payment_installments` | INT | Nullable | Number of installments chosen for the payment. |
| `payment_value` | NUMERIC | Nullable | Amount paid in this payment record. |

---

### 8. `staging.order_reviews`
Customer reviews of orders, with a 1-5 score and optional comments.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `review_id` | VARCHAR(32) | **PK (part)** | Identifier of the review. It is **not unique on its own**: the same `review_id` can appear for several orders. |
| `order_id` | VARCHAR(32) | **PK (part)**, **FK** → `orders.order_id` | The order being reviewed. An order can have more than one review. |
| `review_score` | INT | **CHECK** (`valid_score`): value in 1-5 | Satisfaction rating from 1 (very dissatisfied) to 5 (very satisfied). |
| `review_comment_title` | TEXT | Nullable | Optional short title. Mostly empty. |
| `review_comment_message` | TEXT | Nullable | Optional written comment. Often empty, since most customers only give a score. |
| `review_creation_date` | DATE | Nullable | Date the satisfaction survey was sent. Stored as a date. |
| `review_answer_timestamp` | TIMESTAMP | Nullable | When the customer submitted the review. |

The pair `(order_id, review_id)` is the primary key, because it is the only combination that is unique.

---

## Part 2: Analytics Schema

### Overview

A dimensional model with four dimensions, three fact tables, one order dimension that carries delivery metrics, and one helper table for maps.

| Table | Type | Grain (one row per...) | Rows | Built from |
|---|---|---|---:|---|
| `analytics.dim_customer` | Dimension | order-level `customer_id` | 99,441 | `staging.customers` + `staging.geolocation` |
| `analytics.dim_date` | Dimension | calendar day (2016-09-01 to 2018-12-31) | 852 | Generated with `generate_series` |
| `analytics.dim_product` | Dimension | product | 32,951 | `staging.products` |
| `analytics.dim_seller` | Dimension | seller | 3,095 | `staging.sellers` + `staging.geolocation` |
| `analytics.dim_order` | Dimension (with derived metrics) | order | 99,441 | `staging.orders` |
| `analytics.fact_order_items` | Fact | order item | 112,650 | `staging.order_items` |
| `analytics.fact_payments` | Fact | payment within an order | 103,886 | `staging.order_payments` |
| `analytics.fact_reviews` | Fact | review of an order | 99,224 | `staging.order_reviews` |
| `analytics.geo_distribution` | Helper (for maps) | one seller or one unique customer | 3,095 sellers + one row per unique customer | `staging.sellers`, `staging.customers`, `staging.geolocation` |

Row counts equal the staging counts because every staging row is copied across.

### Analytics relationships

| Child table | Foreign key column | Parent table | Parent column |
|---|---|---|---|
| `dim_order` | `customer_id` | `dim_customer` | `customer_id` |
| `dim_order` | `purchase_date` | `dim_date` | `date_key` |
| `fact_order_items` | `order_id` | `dim_order` | `order_id` |
| `fact_order_items` | `product_id` | `dim_product` | `product_id` |
| `fact_order_items` | `seller_id` | `dim_seller` | `seller_id` |
| `fact_payments` | `order_id` | `dim_order` | `order_id` |
| `fact_reviews` | `order_id` | `dim_order` | `order_id` |

`geo_distribution` has no foreign keys.

### Column mapping: staging → analytics

| Analytics table | Analytics column | Staging source |
|---|---|---|
| `dim_customer` | `zip_prefix`, `city`, `state` | `customer_zip_code_prefix`, `customer_city`, `customer_state` |
| `dim_customer` | `latitude`, `longitude` | `geolocation.latitude`, `geolocation.longitude` (joined on zip code) |
| `dim_seller` | `zip_prefix`, `city`, `state` | `seller_zip_code_prefix`, `seller_city`, `seller_state` |
| `dim_seller` | `latitude`, `longitude` | `geolocation.latitude`, `geolocation.longitude` (joined on zip code) |
| `dim_product` | `category_en` | `product_category_name` |
| `dim_product` | `description_length`, `photos_qty`, `weight_g` | `product_description_length`, `product_photos_qty`, `product_weight_g` |
| `dim_order` | `status` | `order_status` |
| `fact_payments` | `installments` | `payment_installments` |
| `fact_reviews` | `answer_timestamp` | `review_answer_timestamp` |

---

### 1. `analytics.dim_customer`
Customer dimension, enriched with coordinates. One row per **order-level** `customer_id`, so the same person can appear several times. Use `customer_unique_id` to count real customers.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `customer_id` | VARCHAR(32) | **PK** | Order-level customer ID. Joins to `dim_order`. |
| `customer_unique_id` | VARCHAR(32) | Nullable | Permanent identifier of the real customer. |
| `zip_prefix` | VARCHAR(5) | Nullable | First 5 digits of the postal code. |
| `city` | TEXT | Nullable | Customer city. |
| `state` | TEXT | Nullable | Customer state abbreviation. Used for state filters and the sales-by-state chart. |
| `latitude` | NUMERIC | Nullable | Zip-level latitude from `geolocation` (left join). `NULL` when the zip code has no coordinates. |
| `longitude` | NUMERIC | Nullable | Zip-level longitude from `geolocation` (left join). |

---

### 2. `analytics.dim_date`
Calendar dimension generated for the full range of the data. Used to slice sales by year, quarter, month and weekday.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `date_key` | DATE | **PK** | The calendar date. Joins to `dim_order.purchase_date`. |
| `year` | INT | NOT NULL | Calendar year (e.g., 2017). |
| `quarter` | INT | NOT NULL, **CHECK** 1-4 | Calendar quarter. |
| `month` | INT | NOT NULL, **CHECK** 1-12 | Month number. |
| `month_name` | VARCHAR(20) | NOT NULL | English month name (e.g., `January`), with padding trimmed. |
| `day_of_week` | VARCHAR(20) | NOT NULL | English weekday name (e.g., `Monday`), with padding trimmed. Text sorts alphabetically, so Power BI uses an added day-number column to order weekdays. |

The date range comes from `staging.date_limits`, which found the earliest purchase and the latest estimated delivery or review date.

---

### 3. `analytics.dim_product`
Product dimension with an English category and derived package volume.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `product_id` | VARCHAR(32) | **PK** | Unique identifier of the product. |
| `category_en` | VARCHAR | Nullable | English category name. Missing categories are set to `UNKNOWN`. |
| `description_length` | INT | Nullable | Character count of the description. Missing values are set to `0`. |
| `photos_qty` | INT | Nullable | Number of photos. Missing values are set to `0`. |
| `weight_g` | NUMERIC | Nullable | Weight in grams. Missing values are set to `0`. |
| `volume_cubic_cm` | NUMERIC | Nullable | **Derived:** `length_cm × width_cm × height_cm` of the package. `NULL` if any dimension is missing. |

**Notes**
- `0` here means "unknown", not a real value of zero. It can lower averages of weight, photos and description length.
- Product name length and the separate length, height and width columns are not carried over. Only the combined volume is kept.

---

### 4. `analytics.dim_seller`
Seller dimension, enriched with coordinates.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `seller_id` | VARCHAR(32) | **PK** | Unique identifier of the seller. |
| `zip_prefix` | VARCHAR(5) | Nullable | First 5 digits of the seller's postal code. |
| `city` | VARCHAR | Nullable | Seller city. |
| `state` | VARCHAR | Nullable | Seller state abbreviation. |
| `latitude` | NUMERIC | Nullable | Zip-level latitude from `geolocation` (left join). |
| `longitude` | NUMERIC | Nullable | Zip-level longitude from `geolocation` (left join). |

---

### 5. `analytics.dim_order`
One row per order. Splits timestamps into date and time parts and adds delivery metrics. This is the central table that connects customers, dates and the fact tables.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `order_id` | VARCHAR(32) | **PK** | Unique identifier of the order. |
| `customer_id` | VARCHAR(32) | NOT NULL, **FK** → `dim_customer.customer_id` | The order-level customer ID. |
| `status` | VARCHAR(32) | Nullable | Order status (`delivered`, `shipped`, `canceled`, ...). |
| `purchase_date` | DATE | **FK** → `dim_date.date_key` | Date part of the purchase timestamp. |
| `purchase_time` | TIME | Nullable | Time part of the purchase timestamp. Used for the hour-of-day heatmap. |
| `delivered_date` | DATE | Nullable | Date part of the customer delivery timestamp. `NULL` if not delivered. |
| `delivered_time` | TIME | Nullable | Time part of the customer delivery timestamp. |
| `estimated_delivery` | DATE | Nullable | The promised delivery date. |
| `delivery_days` | INT | Nullable | **Derived:** `delivered_date − purchase_date`, in whole days. `NULL` if not delivered. |
| `is_late` | BOOLEAN | Nullable | **Derived:** `true` if `delivered_date` is **after** `estimated_delivery`; `false` if delivered on or before it; `NULL` if not delivered. |

**Notes**
- Approval and carrier hand-off timestamps are not carried over from staging.
- `is_late` compares **dates**, so an order delivered on the estimated date counts as on time.
- In Power BI, `is_late` is relabelled as *Delayed* / *Not Delayed*, and a separate delay-in-days column is added in Power Query.

---

### 6. `analytics.fact_order_items`
The sales fact table. One row per item. Total sales is `SUM(price)`.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `order_id` | VARCHAR(32) | **PK (part)**, **FK** → `dim_order.order_id` | The order containing the item. |
| `order_item_id` | INT | **PK (part)** | Sequence number of the item in the order. Buying the same product twice gives two rows with the same `product_id` and different `order_item_id`. |
| `product_id` | VARCHAR(32) | NOT NULL, **FK** → `dim_product.product_id` | The product sold. |
| `seller_id` | VARCHAR(32) | NOT NULL, **FK** → `dim_seller.seller_id` | The seller who fulfilled the item. |
| `price` | NUMERIC | Nullable | Item selling price, excluding freight. |
| `freight_value` | NUMERIC | Nullable | Shipping fee for the item. |

`shipping_limit_date` is not carried over from staging.

---

### 7. `analytics.fact_payments`
Payment fact table. One row per payment; an order can have several.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `order_id` | VARCHAR(32) | **PK (part)**, **FK** → `dim_order.order_id` | The order being paid. |
| `payment_sequential` | INT | **PK (part)** | Sequence number of the payment within the order. |
| `payment_type` | VARCHAR | Nullable | Payment method (`credit_card`, `boleto`, `voucher`, `debit_card`, `not_defined`). Formatted for display in Power Query. |
| `installments` | INT | Nullable | Number of installments. |
| `payment_value` | NUMERIC | Nullable | Amount of this payment. |

---

### 8. `analytics.fact_reviews`
Review fact table. Used for average rating and the delay-versus-rating analysis.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `review_id` | VARCHAR(32) | **PK (part)** | Identifier of the review. Not unique on its own. |
| `order_id` | VARCHAR(32) | **PK (part)**, **FK** → `dim_order.order_id` | The order being reviewed. |
| `review_score` | INT | **CHECK** value in 1-5 | Satisfaction rating from 1 to 5. |
| `answer_timestamp` | TIMESTAMP | Nullable | When the customer submitted the review. |

Review comments and the survey creation date are not carried over from staging.

---

### 9. `analytics.geo_distribution`
A helper table for the **map visuals**. It lists every seller and every unique customer once, together with state-level coordinates.

| Column Name | Data Type | Key / Constraint | Description / Business Logic |
| :--- | :--- | :--- | :--- |
| `state` | TEXT | Nullable | State abbreviation of the entity. |
| `zip_prefix` | VARCHAR(5) | Nullable | Zip-code prefix of the entity. |
| `state_lat` | NUMERIC | Nullable | **Average** latitude of all geolocation zip codes in that state. This is a state-level approximation, not the entity's exact location. |
| `state_long` | NUMERIC | Nullable | **Average** longitude of all geolocation zip codes in that state. |
| `entity_id` | VARCHAR(32) | **PK (part)** | `seller_id` for sellers, `customer_unique_id` for customers. |
| `entity_type` | TEXT | **PK (part)**, **CHECK** in (`Customer`, `Seller`) | Whether the row represents a customer or a seller. |

**How the rows are built**
- **Sellers:** one row per seller from `staging.sellers`.
- **Customers:** one row per `customer_unique_id`. When a customer has several `customer_id`s, the row with the lowest `customer_id` supplies the state and zip prefix.
- Both sets are joined to the state average coordinates and combined with `UNION ALL`.

Because coordinates are averaged per state, map bubbles show the **density per state**, not exact street-level positions.

---

## Part 3: Staging vs Analytics at a Glance

| Topic | Staging | Analytics |
|---|---|---|
| Purpose | Reliable relational copy of the data | Reporting model for Power BI |
| Naming | Prefixed column names (`customer_city`, `seller_state`) | Short names (`city`, `state`) |
| Timestamps | Kept as in the source (with `order_estimated_delivery_date` and `review_creation_date` stored as dates) | Split into date and time columns in `dim_order` |
| Missing product data | `NULL` | `UNKNOWN` category and `0` for missing numeric metadata |
| Derived columns | None | `delivery_days`, `is_late`, `volume_cubic_cm` |
| Coordinates | In `geolocation` only | Joined onto customers and sellers, plus state averages in `geo_distribution` |
| Unused columns | All source columns kept | Dropped: product name length, product dimensions (replaced by volume), shipping limit date, order approval and carrier timestamps, review comments and creation date |
