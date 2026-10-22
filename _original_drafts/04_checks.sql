/* UNIQUENESS CHECK */ 

SELECT 
'order_item_id,order_key Uniqueness Check' AS check_name,
COUNT(*) AS failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL'
END AS status

FROM(
SELECT order_item_id,order_key
FROM fact_order_items
GROUP BY order_item_id,order_key
HAVING COUNT(*) > 1
) AS dupes

UNION ALL

SELECT
'order_key, payment_sequential Uniqueness Check' AS check_name,
COUNT(*) failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL'
END AS status
FROM(
SELECT order_key, payment_sequential
FROM fact_payments
GROUP BY order_key,payment_sequential
HAVING COUNT(*) > 1
) AS dupes2

UNION ALL 

SELECT
'review_id,order_key Uniqueness Check' AS check_name,
COUNT(*) failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL'
END AS status
FROM(
SELECT review_id,order_key
FROM fact_reviews
GROUP BY review_id,order_key
HAVING COUNT(*) > 1
) AS dupes3
UNION ALL 

SELECT
'order_id Uniqueness Check' AS check_name,
COUNT(*) failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL'
END AS status
FROM(
SELECT order_id
FROM dim_orders
GROUP BY order_id
HAVING COUNT(*) > 1
) AS dupes4

UNION ALL 

SELECT
'product_id Uniqueness Check' AS check_name,
COUNT(*) failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL'
END AS status
FROM(
SELECT product_id
FROM dim_products
GROUP BY product_id
HAVING COUNT(*) > 1
) AS dupes5

UNION ALL 

SELECT
'customer_id Uniqueness Check' AS check_name,
COUNT(*) failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL'
END AS status
FROM(
SELECT customer_id 
FROM dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1
) AS dupes6

UNION ALL 

SELECT
'seller_id Uniqueness Check' AS check_name,
COUNT(*) failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL'
END AS status
FROM(
SELECT seller_id
FROM dim_sellers
GROUP BY seller_id
HAVING COUNT(*) > 1
) AS dupes7


/* REFERENTIAL INTEGRITY CHECKS */

SELECT 'fact_payments.order_key has parent in dim_orders' AS check_name, COUNT(*) AS failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' 
END AS status 
FROM (
SELECT f.order_key
FROM fact_payments f
LEFT JOIN dim_orders d ON f.order_key = d.order_key
WHERE d.order_key IS NULL ) AS check1

UNION ALL 

SELECT 'fact_order_items.product_key has parent in dim_products' AS check_name,COUNT(*) AS failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' 
END AS status 
FROM (
SELECT f.product_key
FROM fact_order_items f
LEFT JOIN dim_products d ON f.product_key = d.product_key
WHERE d.product_key IS NULL ) AS check2

UNION ALL

SELECT 'fact_order_items.seller_key has parent in dim_sellers' AS check_name,COUNT(*) AS failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' 
END AS status 
FROM (
SELECT f.seller_key
FROM fact_order_items f
LEFT JOIN dim_sellers d ON f.seller_key = d.seller_key
WHERE d.seller_key IS NULL ) AS check3

UNION ALL

SELECT 'fact_order_items.order_key has parent in dim_orders' AS check_name,COUNT(*) AS failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' 
END AS status 
FROM (
SELECT f.order_key
FROM fact_order_items f
LEFT JOIN dim_orders d ON f.seller_key = d.order_key
WHERE d.order_key IS NULL ) AS check4

UNION ALL

SELECT 'fact_order_items.shipping_limit_date_key has parent in dim_date' AS check_name,COUNT(*) AS failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' 
END AS status 
FROM (
SELECT f.shipping_limit_date_key
FROM fact_order_items f
LEFT JOIN dim_date d ON f.shipping_limit_date_key = d.date_key
WHERE d.date_key IS NULL
) AS check5

UNION ALL


SELECT 'fact_reviews.order_key has parent in dim_orders' AS check_name,COUNT(*) AS failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' 
END AS status 
FROM (
SELECT f.order_key
FROM fact_reviews f
LEFT JOIN dim_orders d ON f.order_key = d.order_key
WHERE d.order_key IS NULL ) AS check5

UNION ALL

SELECT 'fact_reviews.review_creation_key has parent in dim_date' AS check_name,COUNT(*) AS failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' 
END AS status 
FROM (
SELECT f.review_creation_key
FROM fact_reviews f
LEFT JOIN dim_date d ON f.review_creation_key = d.date_key
WHERE d.date_key IS NULL ) AS check6


UNION ALL

SELECT 'fact_reviews.review_answer_timestamp_key has parent in dim_date' AS check_name,COUNT(*) AS failing_rows,
CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' 
END AS status 
FROM (
SELECT f.review_answer_timestamp_key
FROM fact_reviews f
LEFT JOIN dim_date d ON f.review_answer_timestamp_key = d.date_key
WHERE d.date_key IS NULL ) AS check7


SELECT * 

FROM fact_order_items f
LEFT JOIN dim_date d ON f.shipping_limit_date_key = d.date_key
WHERE d.date_key IS NULL


/* ROW COUNT PARITY */

SELECT 
'raw olist_orders vs dim_orders' AS check_name,
raw_row_count,
transformed_row_count,
raw_row_count - transformed_row_count AS diff,
CASE WHEN raw_row_count = transformed_row_count THEN 'pass' ELSE 'fail' 
END AS status
FROM(
SELECT
(SELECT COUNT(*) FROM raw_olist_orders) AS raw_row_count,
(SELECT COUNT(*) FROM dim_orders) AS transformed_row_count
) AS check1

UNION ALL

SELECT 
'raw olist_customers vs dim_customers' AS check_name,
raw_row_count,
transformed_row_count,
raw_row_count - transformed_row_count AS diff,
CASE WHEN raw_row_count = transformed_row_count THEN 'pass' ELSE 'fail' 
END AS status
FROM(
SELECT
(SELECT COUNT(*) FROM raw_olist_customers) AS raw_row_count,
(SELECT COUNT(*) FROM dim_customers) AS transformed_row_count
) AS check2

UNION ALL

SELECT 
'raw olist_sellers vs dim_sellers' AS check_name,
raw_row_count,
transformed_row_count,
raw_row_count - transformed_row_count AS diff,
CASE WHEN raw_row_count = transformed_row_count THEN 'pass' ELSE 'fail' 
END AS status
FROM(
SELECT
(SELECT COUNT(*) FROM raw_olist_sellers) AS raw_row_count,
(SELECT COUNT(*) FROM dim_sellers) AS transformed_row_count
) AS check3

UNION ALL

SELECT 
'raw olist_products vs dim_customers' AS check_name,
raw_row_count,
transformed_row_count,
raw_row_count - transformed_row_count AS diff,
CASE WHEN raw_row_count = transformed_row_count THEN 'pass' ELSE 'fail' 
END AS status
FROM(
SELECT
(SELECT COUNT(*) FROM raw_olist_products) AS raw_row_count,
(SELECT COUNT(*) FROM dim_products) AS transformed_row_count
) AS check4

UNION ALL

SELECT 
'raw olist_order_items vs fact_order_items' AS check_name,
raw_row_count,
transformed_row_count,
raw_row_count - transformed_row_count AS diff,
CASE WHEN raw_row_count = transformed_row_count THEN 'pass' ELSE 'fail' 
END AS status
FROM(
SELECT
(SELECT COUNT(*) FROM raw_olist_order_items) AS raw_row_count,
(SELECT COUNT(*) FROM fact_order_items) AS transformed_row_count
) AS check5

UNION ALL

SELECT 
'raw olist_order_payments vs fact_payments' AS check_name,
raw_row_count,
transformed_row_count,
raw_row_count - transformed_row_count AS diff,
CASE WHEN raw_row_count = transformed_row_count THEN 'pass' ELSE 'fail' 
END AS status
FROM(
SELECT
(SELECT COUNT(*) FROM raw_olist_order_payments) AS raw_row_count,
(SELECT COUNT(*) FROM fact_payments) AS transformed_row_count
) AS check6

UNION ALL

SELECT 
'raw olist_order_reviews vs fact_reviews' AS check_name,
raw_row_count,
transformed_row_count,
raw_row_count - transformed_row_count AS diff,
CASE WHEN raw_row_count = transformed_row_count THEN 'pass' ELSE 'fail' 
END AS status
FROM(
SELECT
(SELECT COUNT(*) FROM raw_olist_order_reviews) AS raw_row_count,
(SELECT COUNT(*) FROM fact_reviews) AS transformed_row_count
) AS check7