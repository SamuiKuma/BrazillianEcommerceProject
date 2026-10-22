SELECT * FROM raw_olist_sellers

WHERE order_id = 
GROUP BY order_id

SELECT TOP 5 order_id, LEN(order_id) FROM dbo.raw_olist_orders;

IF OBJECT_ID ('transformed_olist_order_items','U') IS NOT NULL
	DROP TABLE transformed_olist_order_items;
CREATE TABLE transformed_olist_order_items (
order_id VARCHAR(50) PRIMARY KEY NOT NULL, order_item_qty VARCHAR(50) , product_id VARCHAR(50), seller_id VARCHAR(50),shipping_limit_date DATETIME, price INT, freight_value INT
)

IF OBJECT_ID ('transformed_olist_customers','U') IS NOT NULL
	DROP TABLE transformed_olist_customers;
CREATE TABLE transformed_olist_customers (
customer_id VARCHAR(50), customer_unique_id VARCHAR(50) PRIMARY KEY NOT NULL, customer_zip_code_prefix INT, customer_city NVARCHAR(50), customer_state VARCHAR(50)
)

IF OBJECT_ID ('transformed_olist_order_payments','U') IS NOT NULL
	DROP TABLE transformed_olist_customers;
CREATE TABLE transformed_olist_customers (
order_id VARCHAR(50) PRIMARY KEY NOT NULL, payment_sequential INT, payment_type VARCHAR(50), payment_installments INT, payment_value INT
)

IF OBJECT_ID ('transformed_olist_order_reviews','U') IS NOT NULL
	DROP TABLE transformed_olist_order_reviews;
CREATE TABLE transformed_olist_order_review (
review_id VARCHAR(50), order_id VARCHAR(50),review_score INT, review_comment_title NVARCHAR(50), review_comment_message NVARCHAR (520), review_creation_date DATETIME, review_answer_timestamp DATETIME
)

IF OBJECT_ID ('transformed_olist_geolocation','U') IS NOT NULL
	DROP TABLE transformed_olist_geolocation;
CREATE TABLE transformed_olist_geolocation (
geolocation_zip_code_prefix VARCHAR(50), geolocation_lat INT, geolocation_lng INT, geolocation_city NVARCHAR(50), geolocation_state VARCHAR(50)
)

GO

IF OBJECT_ID ('transformed_olist_orders','U') IS NOT NULL
	DROP TABLE transformed_olist_orders;
CREATE TABLE transformed_olist_orders (
order_id VARCHAR(50), customer_id VARCHAR(50), order_status VARCHAR(50), order_purchase_timestamp DATETIME, order_approved_at DATETIME, order_delivered_carrier_date DATETIME, order_delivered_customer_date DATETIME, order_estimated_delivery_date DATETIME

)

IF OBJECT_ID ('transformed_olist_sellers','U') IS NOT NULL
	DROP TABLE transformed_olist_sellers;
CREATE TABLE transformed_olist_sellers (
seller_id VARCHAR(50) NOT NULL PRIMARY KEY, seller_zip_code_prefix VARCHAR(50), seller_city VARCHAR(50), seller_state VARCHAR(50)
)

IF OBJECT_ID ('transformed_olist_products','U') IS NOT NULL
	DROP TABLE transformed_olist_products;
CREATE TABLE transformed_olist_products (
product_id VARCHAR(50) NOT NULL PRIMARY KEY, product_category_name NVARCHAR(50), product_name_length INT, product_description_length INT, product_photos_qty INT,product_weight_g INT,product_length_cm INT, product_height INT,product_width_cm INT
)

UPDATE transformed_olist_order_items 
	SET customer_id = REPLACE(customer_id,'"','')
	


	SET geolocation_zip_code_prefix = REPLACE(geolocation_zip_code_prefix,'"','')





INSERT INTO	transformed_olist_customers(
order_id , payment_sequential , payment_type , payment_installments, payment_value)

SELECT

FROM raw_olist_customers


INSERT INTO transformed_olist_geolocation 
/* WINDOW FUNCTION TO DEDUPLICATE GEOLOCATION */

WITH ranked_geolocation AS(
SELECT *, ROW_NUMBER()
OVER (
PARTITION BY geolocation_zip_code_prefix ORDER BY geolocation_lat, geolocation_lng ) AS Number
FROM raw_olist_geolocation
)
SELECT *
FROM ranked_geolocation
WHERE Number = 1;


SELECT * from raw_olist_order_items
SELECT COUNT(DISTINCT(order_id)),count(*) FROM raw_olist_order_items

/* raw_olist orders*/
SELECT 
MIN(TRY_CAST(order_purchase_timestamp AS DATETIME2)) AS order_purchase_timestamp_min, 
MIN(TRY_CAST(NULLIF(TRIM(order_approved_at), '') AS DATETIME2)) AS order_approved_at_min,
MIN(TRY_CAST(order_delivered_carrier_date AS DATETIME2)) AS order_delivered_carr_min, 
MIN(TRY_CAST(order_delivered_customer_date AS DATETIME2)) AS order_del_cust_min, 
MIN(TRY_CAST(order_estimated_delivery_date AS DATETIME2)) AS order_est_date_min, 

MAX(TRY_CAST(order_purchase_timestamp AS DATETIME2)) AS order_purchase_timestamp_max,
MAX(TRY_CAST(order_approved_at AS DATETIME)) AS order_approved_at_max, 
MAX(TRY_CAST(order_delivered_carrier_date AS DATETIME2)) AS order_delivered_carr_max,
MAX(TRY_CAST(order_delivered_customer_date AS DATETIME2)) AS order_del_cust_max, 
MAX(TRY_CAST(order_estimated_delivery_date AS DATETIME2)) AS order_est_date_max 

from raw_olist_orders 


/* raw_olist orders*/
SELECT 
MIN(TRY_CAST(order_purchase_timestamp AS DATETIME2)) AS order_purchase_timestamp_min, 
MIN(TRY_CAST(NULLIF(TRIM(order_approved_at), '') AS DATETIME2)) AS order_approved_at_min,
MIN(TRY_CAST(order_delivered_carrier_date AS DATETIME2)) AS order_delivered_carr_min, 
MIN(TRY_CAST(order_delivered_customer_date AS DATETIME2)) AS order_del_cust_min, 
MIN(TRY_CAST(order_estimated_delivery_date AS DATETIME2)) AS order_est_date_min, 

MAX(TRY_CAST(order_purchase_timestamp AS DATETIME2)) AS order_purchase_timestamp_max,
MAX(TRY_CAST(order_approved_at AS DATETIME)) AS order_approved_at_max, 
MAX(TRY_CAST(order_delivered_carrier_date AS DATETIME2)) AS order_delivered_carr_max,
MAX(TRY_CAST(order_delivered_customer_date AS DATETIME2)) AS order_del_cust_max, 
MAX(TRY_CAST(order_estimated_delivery_date AS DATETIME2)) AS order_est_date_max 

from raw_olist_orders 



SELECT * from raw_olist_orders

SELECT order_approved_at, TRY_CAST(order_approved_at AS DATETIME2),order_status
FROM raw_olist_orders
WHERE TRY_CAST(order_approved_at AS DATETIME2) < '2010-01-01'

SELECT order_status,COUNT(*)
FROM raw_olist_orders
WHERE NULLIF(TRIM(order_approved_at),'') IS NULL
GROUP BY order_status



/* A */

DECLARE @dates TABLE(dt DATE)    
DECLARE @dateFrom DATE
DECLARE @dateTo DATE

SET @dateFrom = '2016/01/01'
SET @dateTo = '2021/01/12'

WHILE(@dateFrom <= @dateTo)
BEGIN
   INSERT INTO @dates 
   SELECT @dateFrom

   SELECT @dateFrom = DATEADD(day, 1, @dateFrom)
END



SELECT * FROM @dates

/* DIM DATE TABLE*/
CREATE TABLE dim_date(
date_key INT PRIMARY KEY NOT NULL , date_value DATE, year INT, quarter INT, month INT, month_name NVARCHAR(10), day INT, day_of_week INT, is_weekend BIT)


INSERT INTO dim_date (date_key, date_value, year, quarter, month, month_name, day, day_of_week, is_weekend)

SELECT 
CAST(CONVERT(CHAR(8),dt,112) AS INT),
dt,
DATEPART(year,dt),
DATEPART(quarter,dt),
DATEPART(month,dt),
DATENAME(month,dt),
DATEPART(day,dt),
DATEPART(weekday,dt),
CASE WHEN
DATEPART(weekday,dt) IN (7,1)
THEN 1 ELSE 0 

END  

FROM @dates

SELECT COUNT(*) FROM dim_date

SELECT TOP 20 * FROM dim_date ORDER BY date_value;



/* geolocation_dim */
WITH ranked_geolocation AS(
SELECT *, ROW_NUMBER()
OVER (
PARTITION BY geolocation_zip_code_prefix ORDER BY geolocation_lat, geolocation_lng ) AS Number
FROM raw_olist_geolocation
)
SELECT REPLACE(geolocation_zip_code_prefix,'"','') AS geolocation_zip_code_prefix,geolocation_lat,geolocation_lng, geolocation_city,
geolocation_state INTO dim_geolocation FROM ranked_geolocation
WHERE Number = 1;


SELECT * FROM raw_olist_sellers;

SELECT TOP 10 * FROM dim_customers;

SELECT * FROM dim_geolocation

SELECT COUNT(*) FROM dim_customers WHERE customer_lat IS NULL;

/* dim_sellers */
CREATE TABLE dim_sellers(
seller_key INT IDENTITY PRIMARY KEY,
seller_id VARCHAR(50),
seller_zip_code_prefix VARCHAR(10),
seller_city NVARCHAR(50),
seller_state VARCHAR(2),
seller_lat DECIMAL(9,6),
seller_lng DECIMAL(9,6)
)

INSERT INTO dim_sellers(seller_id,seller_zip_code_prefix,
seller_city,seller_state,
seller_lat,seller_lng) 
SELECT REPLACE(seller_id,'"','') AS seller_id,
REPLACE(seller_zip_code_prefix,'"','') AS seller_zip_code_prefix,
seller_city,
RIGHT(seller_state,2) AS seller_state, g.geolocation_lat, g.geolocation_lng

FROM raw_olist_sellers s 
LEFT JOIN dim_geolocation g ON REPLACE(s.seller_zip_code_prefix,'"','') = g.geolocation_zip_code_prefix;

SELECT * FROM raw_olist_products

SELECT product_photos_qty,COUNT(*) FROM raw_olist_products
WHERE NULLIF(TRIM(product_photos_qty),'')IS NULL
GROUP BY product_photos_qty


/* dim_products */

CREATE TABLE dim_products(
product_key INT IDENTITY PRIMARY KEY,
product_id VARCHAR(50),
product_category_name NVARCHAR(50),
product_name_length INT,
product_description_length INT,
product_photos_qty INT,
product_weight_g INT,
product_length_cm INT,
product_height_cm INT,
product_width_cm INT
)

INSERT INTO dim_products(
product_id,
product_category_name,
product_name_length,
product_description_length,
product_photos_qty,
product_weight_g,
product_length_cm,
product_height_cm,
product_width_cm
)

SELECT
REPLACE(product_id,'"','') AS product_id, 
NULLIF(TRIM(product_category_name), '') AS product_category_name,
TRY_CAST(NULLIF(TRIM(product_name_lenght),'') AS INT),
TRY_CAST(NULLIF(TRIM(product_description_lenght),'') AS INT),
TRY_CAST(NULLIF(TRIM(product_photos_qty), '') AS INT),
TRY_CAST(NULLIF(TRIM(product_weight_g), '') AS INT),
TRY_CAST(NULLIF(TRIM(product_length_cm), '') AS INT),
TRY_CAST(NULLIF(TRIM(product_height_cm), '') AS INT),
TRY_CAST(NULLIF(TRIM(product_width_cm), '') AS INT)

FROM raw_olist_products
/* 32951 */
SELECT COUNT(*) FROM dim_products;
/* 32951 */
SELECT COUNT(*) FROM raw_olist_products

SELECT COUNT(*) FROM dim_products WHERE product_category_name IS NULL;
SELECT COUNT(*) FROM dim_products WHERE product_photos_qty IS NULL;


/* dim_orders */
CREATE TABLE dim_orders(
order_key INT IDENTITY PRIMARY KEY,
order_id VARCHAR(50),
customer_key INT FOREIGN KEY REFERENCES dim_customers(customer_key),
order_status VARCHAR(50),
order_purchase_timestamp DATETIME,
order_purchase_date_key INT FOREIGN KEY REFERENCES dim_date(date_key),
order_approved_date DATETIME,
order_approved_date_key INT FOREIGN KEY REFERENCES dim_date(date_key),
order_delivered_carrier_date DATETIME,
order_delivered_carrier_date_key INT FOREIGN KEY REFERENCES dim_date(date_key),
order_delivered_customer_date DATETIME,
order_delivered_customer_date_key INT FOREIGN KEY REFERENCES dim_date(date_key),
order_estimated_delivery_date DATETIME,
order_estimated_delivery_date_key INT FOREIGN KEY REFERENCES dim_date(date_key)
)

INSERT INTO dim_orders(
order_id,
customer_key,
order_status,
order_purchase_timestamp,
order_purchase_date_key ,
order_approved_date,
order_approved_date_key ,
order_delivered_carrier_date,
order_delivered_carrier_date_key ,
order_delivered_customer_date,
order_delivered_customer_date_key,
order_estimated_delivery_date,
order_estimated_delivery_date_key
)
SELECT REPLACE(order_id,'"','') AS order_id, customers.customer_key,order_status,
TRY_CAST(NULLIF(TRIM(order_purchase_timestamp), '') AS DATETIME2),
purchase.date_key,
TRY_CAST(NULLIF(TRIM(order_approved_at), '') AS DATETIME2),
approved.date_key,
TRY_CAST(NULLIF(TRIM(order_delivered_carrier_date), '') AS DATETIME2),
carrier.date_key,
TRY_CAST(NULLIF(TRIM(order_delivered_customer_date), '') AS DATETIME2),
customer.date_key,
TRY_CAST(NULLIF(TRIM(order_estimated_delivery_date), '') AS DATETIME2),
delivery.date_key
FROM raw_olist_orders orders
INNER JOIN dim_customers customers ON REPLACE(orders.customer_id,'"','') = customers.customer_id
LEFT JOIN dim_date purchase ON CAST(TRY_CAST(NULLIF(TRIM(LEFT(orders.order_purchase_timestamp,10)),'')AS DATETIME2) AS DATE) = purchase.date_value
LEFT JOIN dim_date approved ON CAST(TRY_CAST(NULLIF(TRIM(LEFT(orders.order_approved_at,10)),'')AS DATETIME2) AS DATE) = approved.date_value
LEFT JOIN dim_date carrier ON CAST(TRY_CAST(NULLIF(TRIM(LEFT(orders.order_delivered_carrier_date,10)),'')AS DATETIME2) AS DATE)= carrier.date_value
LEFT JOIN dim_date customer ON CAST(TRY_CAST(NULLIF(TRIM(LEFT(orders.order_delivered_customer_date,10)),'')AS DATETIME2) AS DATE)= customer.date_value
LEFT JOIN dim_date delivery ON CAST(TRY_CAST(NULLIF(TRIM(LEFT(orders.order_estimated_delivery_date,10)),'')AS DATETIME2) AS DATE) = delivery.date_value


SELECT COUNT(*) 
FROM raw_olist_orders o
INNER JOIN dim_customers customers ON REPLACE(o.customer_id,'"','') = customers.customer_id



SELECT COUNT(*) FROM dim_orders;

SELECT COUNT(*) FROM raw_olist_orders

SELECT TOP 5 customer_id, LEN(customer_id) FROM raw_olist_orders

SELECT COUNT(*) FROM dim_orders WHERE order_purchase_date_key IS NULL;

SELECT COUNT(*) FROM dim_orders WHERE order_approved_date_key IS NULL;

SELECT TOP 10 * FROM dim_orders;

/*customers_dim*/
CREATE TABLE dim_customers(
customer_key INT IDENTITY PRIMARY KEY,
customer_id VARCHAR(50),
customer_unique_id VARCHAR(50),
customer_zip_code_prefix VARCHAR(10),
customer_city NVARCHAR(100),
customer_state VARCHAR(2),
customer_lat DECIMAL(9,6),
customer_lng DECIMAL(9,6)
)

INSERT INTO dim_customers(customer_id, customer_unique_id, customer_zip_code_prefix, 
customer_city, customer_state, customer_lat, customer_lng)
SELECT REPLACE(customer_id,'"','') AS customer_id, REPLACE(customer_unique_id,'"','') AS customer_unique_id, REPLACE(customer_zip_code_prefix,'"','') AS customer_zip_code_prefix, customer_city, customer_state,g.geolocation_lat, g.geolocation_lng
FROM raw_olist_customers c
LEFT JOIN dim_geolocation g ON REPLACE(c.customer_zip_code_prefix,'"','') = g.geolocation_zip_code_prefix;


select * from raw_olist_customers
select * from raw_olist_order_payments

SELECT TOP 5 order_estimated_delivery_date, LEFT(order_estimated_delivery_date, 10) FROM raw_olist_orders


