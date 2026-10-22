/*
    04_checks.sql
    Layer : DATA QUALITY
    Run   : after 03_facts.sql (and again any time you reload). Read-only - it only creates a temp table.

    One result set. Every check returns the number of failing rows, and a status:
      PASS = 0 failing rows
      FAIL = a real pipeline problem, fix before using the data
      WARN = a known data quality issue in the Olist source data; it is reported, not "fixed",
             and the analysis queries handle it explicitly (see the notes in 05_analysis.sql)
*/

USE Brazillian_Ecommerce;
GO

SET NOCOUNT ON;

CREATE TABLE #check_results (
    check_group   VARCHAR(30)   NOT NULL,
    check_name    VARCHAR(120)  NOT NULL,
    failing_rows  INT           NOT NULL,
    severity      VARCHAR(4)    NOT NULL      -- what a non-zero result means: FAIL or WARN
);

/* ---------- 1. Uniqueness: is each table really at the grain we say it is? ---------- */

INSERT INTO #check_results VALUES
('Uniqueness', 'dim_orders.order_id', (SELECT COUNT(*) FROM (SELECT order_id FROM dbo.dim_orders GROUP BY order_id HAVING COUNT(*) > 1) d), 'FAIL'),
('Uniqueness', 'dim_customers.customer_id', (SELECT COUNT(*) FROM (SELECT customer_id FROM dbo.dim_customers GROUP BY customer_id HAVING COUNT(*) > 1) d), 'FAIL'),
('Uniqueness', 'dim_products.product_id', (SELECT COUNT(*) FROM (SELECT product_id FROM dbo.dim_products GROUP BY product_id HAVING COUNT(*) > 1) d), 'FAIL'),
('Uniqueness', 'dim_sellers.seller_id', (SELECT COUNT(*) FROM (SELECT seller_id FROM dbo.dim_sellers GROUP BY seller_id HAVING COUNT(*) > 1) d), 'FAIL'),
('Uniqueness', 'dim_geolocation.zip_code_prefix', (SELECT COUNT(*) FROM (SELECT geolocation_zip_code_prefix FROM dbo.dim_geolocation GROUP BY geolocation_zip_code_prefix HAVING COUNT(*) > 1) d), 'FAIL'),
('Uniqueness', 'fact_order_items (order_key, order_item_id)', (SELECT COUNT(*) FROM (SELECT order_key, order_item_id FROM dbo.fact_order_items GROUP BY order_key, order_item_id HAVING COUNT(*) > 1) d), 'FAIL'),
('Uniqueness', 'fact_payments (order_key, payment_sequential)', (SELECT COUNT(*) FROM (SELECT order_key, payment_sequential FROM dbo.fact_payments GROUP BY order_key, payment_sequential HAVING COUNT(*) > 1) d), 'FAIL'),
('Uniqueness', 'fact_reviews (review_id, order_key)', (SELECT COUNT(*) FROM (SELECT review_id, order_key FROM dbo.fact_reviews GROUP BY review_id, order_key HAVING COUNT(*) > 1) d), 'FAIL');

/* ---------- 2. Referential integrity: every key points at a real parent row ---------- */
-- NULL keys are not orphans, so only non-NULL values are tested

INSERT INTO #check_results VALUES
('Referential integrity', 'dim_orders.customer_key -> dim_customers',
    (SELECT COUNT(*) FROM dbo.dim_orders o WHERE NOT EXISTS (SELECT 1 FROM dbo.dim_customers c WHERE c.customer_key = o.customer_key)), 'FAIL'),
('Referential integrity', 'fact_order_items.order_key -> dim_orders',
    (SELECT COUNT(*) FROM dbo.fact_order_items f WHERE NOT EXISTS (SELECT 1 FROM dbo.dim_orders d WHERE d.order_key = f.order_key)), 'FAIL'),
('Referential integrity', 'fact_order_items.product_key -> dim_products',
    (SELECT COUNT(*) FROM dbo.fact_order_items f WHERE NOT EXISTS (SELECT 1 FROM dbo.dim_products d WHERE d.product_key = f.product_key)), 'FAIL'),
('Referential integrity', 'fact_order_items.seller_key -> dim_sellers',
    (SELECT COUNT(*) FROM dbo.fact_order_items f WHERE NOT EXISTS (SELECT 1 FROM dbo.dim_sellers d WHERE d.seller_key = f.seller_key)), 'FAIL'),
('Referential integrity', 'fact_order_items.shipping_limit_date_key -> dim_date',
    (SELECT COUNT(*) FROM dbo.fact_order_items f WHERE f.shipping_limit_date_key IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.dim_date d WHERE d.date_key = f.shipping_limit_date_key)), 'FAIL'),
('Referential integrity', 'fact_payments.order_key -> dim_orders',
    (SELECT COUNT(*) FROM dbo.fact_payments f WHERE NOT EXISTS (SELECT 1 FROM dbo.dim_orders d WHERE d.order_key = f.order_key)), 'FAIL'),
('Referential integrity', 'fact_reviews.order_key -> dim_orders',
    (SELECT COUNT(*) FROM dbo.fact_reviews f WHERE NOT EXISTS (SELECT 1 FROM dbo.dim_orders d WHERE d.order_key = f.order_key)), 'FAIL'),
('Referential integrity', 'fact_reviews.review_creation_key -> dim_date',
    (SELECT COUNT(*) FROM dbo.fact_reviews f WHERE f.review_creation_key IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.dim_date d WHERE d.date_key = f.review_creation_key)), 'FAIL'),
('Referential integrity', 'fact_reviews.review_answer_timestamp_key -> dim_date',
    (SELECT COUNT(*) FROM dbo.fact_reviews f WHERE f.review_answer_timestamp_key IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.dim_date d WHERE d.date_key = f.review_answer_timestamp_key)), 'FAIL');

/* ---------- 3. Row count parity: raw vs transformed (failing_rows = the difference) ---------- */
-- Every raw row is expected to survive, so any difference means a join dropped or multiplied rows

INSERT INTO #check_results VALUES
('Row count parity', 'raw_olist_orders vs dim_orders',
    (SELECT ABS((SELECT COUNT(*) FROM dbo.raw_olist_orders) - (SELECT COUNT(*) FROM dbo.dim_orders))), 'FAIL'),
('Row count parity', 'raw_olist_customers vs dim_customers',
    (SELECT ABS((SELECT COUNT(*) FROM dbo.raw_olist_customers) - (SELECT COUNT(*) FROM dbo.dim_customers))), 'FAIL'),
('Row count parity', 'raw_olist_sellers vs dim_sellers',
    (SELECT ABS((SELECT COUNT(*) FROM dbo.raw_olist_sellers) - (SELECT COUNT(*) FROM dbo.dim_sellers))), 'FAIL'),
('Row count parity', 'raw_olist_products vs dim_products',
    (SELECT ABS((SELECT COUNT(*) FROM dbo.raw_olist_products) - (SELECT COUNT(*) FROM dbo.dim_products))), 'FAIL'),
('Row count parity', 'raw_olist_order_items vs fact_order_items',
    (SELECT ABS((SELECT COUNT(*) FROM dbo.raw_olist_order_items) - (SELECT COUNT(*) FROM dbo.fact_order_items))), 'FAIL'),
('Row count parity', 'raw_olist_order_payments vs fact_payments',
    (SELECT ABS((SELECT COUNT(*) FROM dbo.raw_olist_order_payments) - (SELECT COUNT(*) FROM dbo.fact_payments))), 'FAIL'),
('Row count parity', 'raw_olist_order_reviews vs fact_reviews',
    (SELECT ABS((SELECT COUNT(*) FROM dbo.raw_olist_order_reviews) - (SELECT COUNT(*) FROM dbo.fact_reviews))), 'FAIL');

/* ---------- 4. Value reconciliation: money totals match the raw files ---------- */
-- Compares the sum of the raw text values (converted here) with the sum in the fact table

INSERT INTO #check_results VALUES
('Reconciliation', 'SUM(price): raw vs fact_order_items',
    (SELECT CASE WHEN (SELECT SUM(TRY_CAST(price AS DECIMAL(18,2))) FROM dbo.raw_olist_order_items) = (SELECT SUM(price) FROM dbo.fact_order_items) THEN 0 ELSE 1 END), 'FAIL'),
('Reconciliation', 'SUM(freight_value): raw vs fact_order_items',
    (SELECT CASE WHEN (SELECT SUM(TRY_CAST(freight_value AS DECIMAL(18,2))) FROM dbo.raw_olist_order_items) = (SELECT SUM(freight_value) FROM dbo.fact_order_items) THEN 0 ELSE 1 END), 'FAIL'),
('Reconciliation', 'SUM(payment_value): raw vs fact_payments',
    (SELECT CASE WHEN (SELECT SUM(TRY_CAST(payment_value AS DECIMAL(18,2))) FROM dbo.raw_olist_order_payments) = (SELECT SUM(payment_value) FROM dbo.fact_payments) THEN 0 ELSE 1 END), 'FAIL');

/* ---------- 5. Conversion loss: a value existed in raw but TRY_CAST turned it into NULL ---------- */

INSERT INTO #check_results VALUES
('Conversion loss', 'order_purchase_timestamp',
    (SELECT COUNT(*) FROM dbo.raw_olist_orders WHERE NULLIF(TRIM(order_purchase_timestamp), '') IS NOT NULL) - (SELECT COUNT(order_purchase_timestamp) FROM dbo.dim_orders), 'FAIL'),
('Conversion loss', 'order_approved_at',
    (SELECT COUNT(*) FROM dbo.raw_olist_orders WHERE NULLIF(TRIM(order_approved_at), '') IS NOT NULL) - (SELECT COUNT(order_approved_date) FROM dbo.dim_orders), 'FAIL'),
('Conversion loss', 'order_delivered_carrier_date',
    (SELECT COUNT(*) FROM dbo.raw_olist_orders WHERE NULLIF(TRIM(order_delivered_carrier_date), '') IS NOT NULL) - (SELECT COUNT(order_delivered_carrier_date) FROM dbo.dim_orders), 'FAIL'),
('Conversion loss', 'order_delivered_customer_date',
    (SELECT COUNT(*) FROM dbo.raw_olist_orders WHERE NULLIF(TRIM(order_delivered_customer_date), '') IS NOT NULL) - (SELECT COUNT(order_delivered_customer_date) FROM dbo.dim_orders), 'FAIL'),
('Conversion loss', 'order_estimated_delivery_date',
    (SELECT COUNT(*) FROM dbo.raw_olist_orders WHERE NULLIF(TRIM(order_estimated_delivery_date), '') IS NOT NULL) - (SELECT COUNT(order_estimated_delivery_date) FROM dbo.dim_orders), 'FAIL'),
('Conversion loss', 'review_creation_date / review_answer_timestamp',
    (SELECT COUNT(*) FROM dbo.raw_olist_order_reviews WHERE NULLIF(TRIM(review_creation_date), '') IS NOT NULL) - (SELECT COUNT(review_creation_date) FROM dbo.fact_reviews)
  + (SELECT COUNT(*) FROM dbo.raw_olist_order_reviews WHERE NULLIF(TRIM(review_answer_timestamp), '') IS NOT NULL) - (SELECT COUNT(review_answer_timestamp) FROM dbo.fact_reviews), 'FAIL'),
('Conversion loss', 'shipping_limit_date',
    (SELECT COUNT(*) FROM dbo.raw_olist_order_items WHERE NULLIF(TRIM(shipping_limit_date), '') IS NOT NULL) - (SELECT COUNT(shipping_limit_date) FROM dbo.fact_order_items), 'FAIL');

/* ---------- 6. Valid values ---------- */

INSERT INTO #check_results VALUES
('Valid values', 'review_score is between 1 and 5',
    (SELECT COUNT(*) FROM dbo.fact_reviews WHERE review_score NOT BETWEEN 1 AND 5), 'FAIL'),
('Valid values', 'price and freight_value are not negative',
    (SELECT COUNT(*) FROM dbo.fact_order_items WHERE price < 0 OR freight_value < 0), 'FAIL'),
('Valid values', 'payment_value is not negative',
    (SELECT COUNT(*) FROM dbo.fact_payments WHERE payment_value < 0), 'FAIL'),
('Valid values', 'order_status is one of the 8 known statuses',
    (SELECT COUNT(*) FROM dbo.dim_orders WHERE order_status NOT IN ('created','approved','invoiced','processing','shipped','delivered','canceled','unavailable')), 'FAIL'),
('Valid values', 'payment_type is one of the 5 known types',
    (SELECT COUNT(*) FROM dbo.fact_payments WHERE payment_type IS NULL OR payment_type NOT IN ('credit_card','boleto','voucher','debit_card','not_defined')), 'FAIL'),
('Valid values', 'state codes are 2 letters (customers, sellers)',
    (SELECT COUNT(*) FROM dbo.dim_customers WHERE LEN(customer_state) <> 2) + (SELECT COUNT(*) FROM dbo.dim_sellers WHERE LEN(seller_state) <> 2), 'FAIL');

/* ---------- 7. Known source-data issues (WARN: reported and handled in the analysis, not deleted) ---------- */

INSERT INTO #check_results VALUES
('Source data', 'delivered orders with no delivery date (excluded from delivery metrics)',
    (SELECT COUNT(*) FROM dbo.dim_orders WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL), 'WARN'),
('Source data', 'non-delivered orders that have a delivery date',
    (SELECT COUNT(*) FROM dbo.dim_orders WHERE order_status <> 'delivered' AND order_delivered_customer_date IS NOT NULL), 'WARN'),
('Source data', 'carrier pickup dated before the purchase',
    (SELECT COUNT(*) FROM dbo.dim_orders WHERE order_delivered_carrier_date < order_purchase_timestamp), 'WARN'),
('Source data', 'customer delivery dated before carrier pickup',
    (SELECT COUNT(*) FROM dbo.dim_orders WHERE order_delivered_customer_date < order_delivered_carrier_date), 'WARN'),
('Source data', 'orders with items but no payment row',
    (SELECT COUNT(*) FROM dbo.dim_orders o WHERE EXISTS (SELECT 1 FROM dbo.fact_order_items i WHERE i.order_key = o.order_key)
                                              AND NOT EXISTS (SELECT 1 FROM dbo.fact_payments p WHERE p.order_key = o.order_key)), 'WARN'),
('Source data', 'orders with payments but no items (never fulfilled; payments are not revenue)',
    (SELECT COUNT(*) FROM dbo.dim_orders o WHERE EXISTS (SELECT 1 FROM dbo.fact_payments p WHERE p.order_key = o.order_key)
                                              AND NOT EXISTS (SELECT 1 FROM dbo.fact_order_items i WHERE i.order_key = o.order_key)), 'WARN'),
('Source data', 'orders where payments differ from items + freight by more than 1 cent',
    (SELECT COUNT(*)
     FROM (SELECT order_key, SUM(price + freight_value) AS items_total FROM dbo.fact_order_items GROUP BY order_key) i
     JOIN (SELECT order_key, SUM(payment_value) AS paid_total FROM dbo.fact_payments GROUP BY order_key) p ON p.order_key = i.order_key
     WHERE ABS(i.items_total - p.paid_total) > 0.01), 'WARN'),
('Source data', 'orders with more than one review',
    (SELECT COUNT(*) FROM (SELECT order_key FROM dbo.fact_reviews GROUP BY order_key HAVING COUNT(*) > 1) x), 'WARN'),
('Source data', 'customers with no lat/lng (zip not usable in geolocation)',
    (SELECT COUNT(*) FROM dbo.dim_customers WHERE customer_lat IS NULL), 'WARN'),
('Source data', 'sellers with no lat/lng (zip not usable in geolocation)',
    (SELECT COUNT(*) FROM dbo.dim_sellers WHERE seller_lat IS NULL), 'WARN'),
('Source data', 'products with no category',
    (SELECT COUNT(*) FROM dbo.dim_products WHERE product_category_name IS NULL), 'WARN');

/* ---------- Result ---------- */

SELECT
    check_group,
    check_name,
    failing_rows,
    CASE WHEN failing_rows = 0 THEN 'PASS' ELSE severity END AS status
FROM #check_results
ORDER BY
    CASE WHEN failing_rows <> 0 AND severity = 'FAIL' THEN 0
         WHEN failing_rows <> 0 THEN 1
         ELSE 2 END,
    check_group, check_name;

DROP TABLE #check_results;
