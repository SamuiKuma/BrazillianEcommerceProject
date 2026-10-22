/* fact_payments */

SELECT DISTINCT payment_type,COUNT(*) FROM raw_olist_order_payments
GROUP BY payment_type

CREATE TABLE fact_payments (
payment_key INT IDENTITY,
order_key INT FOREIGN KEY REFERENCES dim_orders(order_key),
payment_sequential INT,
payment_type VARCHAR(50),
payment_installments INT,
payment_value DECIMAL(18,2),
PRIMARY KEY (order_key,payment_sequential)
)

INSERT INTO fact_payments(
order_key,
payment_sequential,
payment_type,
payment_installments,
payment_value
)
SELECT 

orders.order_key,
TRY_CAST(NULLIF(TRIM(payment_sequential),'') AS INT),
payment_type,
TRY_CAST(NULLIF(TRIM(payment_installments),'') AS INT),
TRY_CAST(NULLIF(TRIM(payment_value),'') AS DECIMAL(18,2))

FROM raw_olist_order_payments p
INNER JOIN dim_orders orders ON REPLACE(p.order_id,'"','') = orders.order_id


/* fact_order_items */

CREATE TABLE fact_order_items(
order_item_key INT IDENTITY PRIMARY KEY,
order_item_id INT,
order_key INT FOREIGN KEY REFERENCES dim_orders(order_key),
product_key INT FOREIGN KEY REFERENCES dim_products(product_key),
seller_key INT FOREIGN KEY REFERENCES dim_sellers(seller_key),
shipping_limit_date DATETIME2,
shipping_limit_date_key INT FOREIGN KEY REFERENCES dim_date(date_key),
price DECIMAL(18,2),
freight_value DECIMAL (18,2)
)

INSERT INTO fact_order_items(
order_key,
order_item_id,
product_key,
seller_key,
shipping_limit_date,
shipping_limit_date_key,
price,
freight_value
) 
SELECT
orders.order_key,
TRY_CAST(NULLIF(TRIM(order_item_id),'') AS INT),
products.product_key,
sellers.seller_key,
TRY_CAST(NULLIF(TRIM(shipping_limit_date),'') AS DATETIME2),
dates.date_key,
TRY_CAST(NULLIF(TRIM(price),'') AS DECIMAL(18,2)),
TRY_CAST(NULLIF(TRIM(freight_value),'') AS DECIMAL(18,2))

FROM raw_olist_order_items order_items
INNER JOIN dim_orders orders ON REPLACE(order_items.order_id,'"','') = orders.order_id
INNER JOIN dim_products products ON REPLACE(order_items.product_id,'"','') = products.product_id
INNER JOIN dim_sellers sellers ON REPLACE(order_items.seller_id,'"','') = sellers.seller_id
LEFT JOIN dim_date dates ON CAST(TRY_CAST(NULLIF(TRIM(LEFT(order_items.shipping_limit_date,10)),'')AS DATETIME2) AS DATE) = dates.date_value



/* fact_reviews */
CREATE TABLE fact_reviews(
review_id VARCHAR(50),
review_key INT IDENTITY,
order_key INT REFERENCES dim_orders(order_key),
review_score INT,
review_comment_title NVARCHAR(50),
review_comment_message NVARCHAR(520),
review_creation_date DATETIME2,
review_creation_key INT FOREIGN KEY REFERENCES dim_date(date_key),
review_answer_timestamp DATETIME2,
review_answer_timestamp_key INT FOREIGN KEY REFERENCES dim_date(date_key)
)
INSERT INTO fact_reviews
(
review_id,
order_key,
review_score,
review_comment_title,
review_comment_message,
review_creation_date,
review_creation_key,
review_answer_timestamp,
review_answer_timestamp_key
)
SELECT
REPLACE(review_id,'"','') AS review_id,
orders.order_key,
TRY_CAST(NULLIF(TRIM(review_score),'') AS INT),
NULLIF(TRIM(review_comment_title),'') AS review_comment_title,
NULLIF(TRIM(review_comment_message),'') AS review_comment_message,
TRY_CAST(NULLIF(TRIM(review_creation_date),'') AS DATETIME2),
creation.date_key,
TRY_CAST(NULLIF(TRIM(review_answer_timestamp),'') AS DATETIME2),
answer.date_key
FROM raw_olist_order_reviews reviews
INNER JOIN dim_orders orders ON REPLACE(reviews.order_id,'"','')  = orders.order_id
LEFT JOIN dim_date creation ON CAST(TRY_CAST(NULLIF(TRIM(LEFT(reviews.review_creation_date,10)),'')AS DATETIME2) AS DATE) = creation.date_value
LEFT JOIN dim_date answer ON CAST(TRY_CAST(NULLIF(TRIM(LEFT(reviews.review_answer_timestamp,10)),'')AS DATETIME2) AS DATE) = answer.date_value
