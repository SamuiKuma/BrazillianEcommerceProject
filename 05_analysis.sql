/*
    05_analysis.sql
    Layer : ANALYSIS (business questions answered from the fact / dimension tables)
    Run   : after 04_checks.sql has no FAIL rows. Run the whole file in one query window - the
            queries after the setup section read the temp tables created there.

    METRIC DEFINITIONS (these are business rules I chose, change them here if your definition differs)
      Revenue        SUM(price) from fact_order_items. Freight is reported separately, never mixed in.
      Booked order   an order that has at least one item and a status other than 'canceled' / 'unavailable'
                     (the customer ordered it and it was not cancelled).
      Realized       a booked order with status 'delivered'.
                     Limit: Olist has no refund/return data, so "realized" means delivered, not "kept".
      Late delivery  delivered_to_customer date is after the estimated delivery date. Compared by DATE
                     because the estimate is stored as a date (00:00:00); comparing timestamps would count an
                     order delivered at 3pm on the promised day as late.
      Order date     order_purchase_timestamp for every time-based metric.
      Customers      count people with customer_unique_id, not customer_id (new customer_id on every order).
      payment_value  only used for the payment mix. It is not revenue: it includes freight, can include
                     installment interest, and 775 payments belong to orders that never had items.

    DATA LIMITS
      * Orders run 2016-09 to 2018-10. 2016 and Sep/Oct 2018 are very thin, so exclude them from trend
        conclusions (the monthly query shows why).
      * Order-level metrics that need reviews use ONE review per order (the latest). Joining raw reviews
        to items or payments would duplicate rows - 547 orders have more than one review.
*/

USE Brazillian_Ecommerce;
GO

SET NOCOUNT ON;

/* ============================================================
   SETUP - one row per order, built once and reused below
   ============================================================ */

/* Booked Orders with Revenue: one row per booked order (items summed first, so nothing is duplicated) */
DROP TABLE IF EXISTS #order_revenue;

SELECT
    o.order_key,
    o.customer_key,
    o.order_status,
    o.order_purchase_date_key,
    COUNT(i.order_item_id)  AS item_count,
    SUM(i.price)            AS item_revenue,
    SUM(i.freight_value)    AS freight_value
INTO #order_revenue
FROM dbo.dim_orders o
INNER JOIN dbo.fact_order_items i ON i.order_key = o.order_key
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY o.order_key, o.customer_key, o.order_status, o.order_purchase_date_key;

/* One review per order: the most recently answered one */
DROP TABLE IF EXISTS #order_review;

SELECT order_key, review_score
INTO #order_review
FROM (
    SELECT order_key, review_score,
           ROW_NUMBER() OVER (PARTITION BY order_key
                              ORDER BY review_answer_timestamp DESC, review_creation_date DESC, review_key DESC) AS rn
    FROM dbo.fact_reviews
) r
WHERE rn = 1;


/* ============================================================
   1. ORDER VOLUME AND STATUS
   Question: how many orders do we have and where are they in the lifecycle?
   ============================================================ */

SELECT
    order_status,
    COUNT(*)                                                       AS order_count,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct_of_orders
FROM dbo.dim_orders
GROUP BY order_status
ORDER BY order_count DESC;


/* ============================================================
   2. BOOKED REVENUE AND REALIZED REVENUE
   Question: how much revenue was booked, and how much of it has actually been delivered?
   Validate: booked + canceled/unavailable item revenue = SUM(price) of fact_order_items
   ============================================================ */

SELECT
    COUNT(*)                                                                           AS booked_orders,
    SUM(item_revenue)                                                                  AS booked_revenue,
    SUM(CASE WHEN order_status = 'delivered' THEN item_revenue END)                    AS realized_revenue,
    CAST(100.0 * SUM(CASE WHEN order_status = 'delivered' THEN item_revenue END)
               / SUM(item_revenue) AS DECIMAL(5,2))                                    AS realized_pct,
    SUM(freight_value)                                                                 AS booked_freight
FROM #order_revenue;

/* Booked revenue by order status (shows what is still in the pipeline) */
SELECT
    order_status,
    COUNT(*)           AS order_count,
    SUM(item_revenue)  AS item_revenue
FROM #order_revenue
GROUP BY order_status
ORDER BY item_revenue DESC;


/* ============================================================
   3. BOOKED REVENUE ORDERS COUNT AND AVERAGE ORDER VALUE (AOV)
   Question: how big is a typical order?
   AOV = booked item revenue / number of booked orders (an order = one order_id, not one item).
   ============================================================ */

SELECT
    COUNT(*)                                                    AS booked_orders,
    SUM(item_revenue)                                           AS booked_revenue,
    CAST(SUM(item_revenue) / COUNT(*) AS DECIMAL(10,2))         AS aov_excl_freight,
    CAST(SUM(item_revenue + freight_value) / COUNT(*) AS DECIMAL(10,2)) AS aov_incl_freight,
    CAST(1.0 * SUM(item_count) / COUNT(*) AS DECIMAL(5,2))      AS avg_items_per_order
FROM #order_revenue;


/* ============================================================
   4. DELIVERY PERFORMANCE AND LATE DELIVERY %
   Question: how often do we miss the promised delivery date?
   Scope: delivered orders that have a delivery date (8 delivered orders have none and are left out).
   ============================================================ */

SELECT
    COUNT(*)                                                                   AS deliveredOrderCount,
    SUM(CASE WHEN order_delivered_customer_date_key > order_estimated_delivery_date_key THEN 1 ELSE 0 END)
                                                                               AS lateOrderCount,
    CAST(100.0 * SUM(CASE WHEN order_delivered_customer_date_key > order_estimated_delivery_date_key THEN 1 ELSE 0 END)
               / COUNT(*) AS DECIMAL(5,2))                                     AS lateDeliveryPct,
    CAST(AVG(1.0 * DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)) AS DECIMAL(5,1))
                                                                               AS avg_days_to_deliver
FROM dbo.dim_orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

/* Late % by purchase month - shows whether delivery got better or worse over time */
SELECT
    d.year,
    d.month,
    COUNT(*)                                                                   AS delivered_orders,
    CAST(100.0 * SUM(CASE WHEN o.order_delivered_customer_date_key > o.order_estimated_delivery_date_key THEN 1 ELSE 0 END)
               / COUNT(*) AS DECIMAL(5,2))                                     AS late_pct
FROM dbo.dim_orders o
INNER JOIN dbo.dim_date d ON d.date_key = o.order_purchase_date_key
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY d.year, d.month
ORDER BY d.year, d.month;


/* ============================================================
   5. CUSTOMER REVIEWS
   Question: how satisfied are customers, and does lateness hurt the score?
   ============================================================ */

/* Average score across all reviews (one row per review) */
SELECT
    COUNT(*)                                        AS review_count,
    CAST(AVG(1.0 * review_score) AS DECIMAL(4,2))   AS avg_review_score
FROM dbo.fact_reviews;

/* Score distribution */
SELECT
    review_score,
    COUNT(*)                                                       AS review_count,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct_of_reviews
FROM dbo.fact_reviews
GROUP BY review_score
ORDER BY review_score;

/* Average score for on-time vs late deliveries (one review per order) */
SELECT
    CASE WHEN o.order_delivered_customer_date_key > o.order_estimated_delivery_date_key
         THEN 'late' ELSE 'on time' END                            AS delivery_result,
    COUNT(*)                                                       AS orders_with_review,
    CAST(AVG(1.0 * r.review_score) AS DECIMAL(4,2))                AS avg_review_score
FROM dbo.dim_orders o
INNER JOIN #order_review r ON r.order_key = o.order_key
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY CASE WHEN o.order_delivered_customer_date_key > o.order_estimated_delivery_date_key
              THEN 'late' ELSE 'on time' END;


/* ============================================================
   6. TIME: MONTHLY ORDERS, REVENUE AND AOV
   Question: how is the business growing?
   Note: 2016 and Sep/Oct 2018 are nearly empty in the dataset - do not read them as trends.
   ============================================================ */

SELECT
    d.year,
    d.month,
    COUNT(*)                                            AS booked_orders,
    SUM(r.item_revenue)                                 AS booked_revenue,
    CAST(SUM(r.item_revenue) / COUNT(*) AS DECIMAL(10,2)) AS aov
FROM #order_revenue r
INNER JOIN dbo.dim_date d ON d.date_key = r.order_purchase_date_key
GROUP BY d.year, d.month
ORDER BY d.year, d.month;


/* ============================================================
   7. PRODUCT: TOP 10 CATEGORIES BY BOOKED REVENUE
   Items are joined to their order only to apply the "booked" rule - still one row per item, no duplication.
   ============================================================ */

SELECT TOP (10)
    p.product_category_name_english                     AS category,
    COUNT(*)                                            AS items_sold,
    SUM(i.price)                                        AS item_revenue,
    CAST(100.0 * SUM(i.price) / SUM(SUM(i.price)) OVER () AS DECIMAL(5,2)) AS pct_of_booked_revenue
FROM dbo.fact_order_items i
INNER JOIN dbo.dim_orders   o ON o.order_key   = i.order_key
INNER JOIN dbo.dim_products p ON p.product_key = i.product_key
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY p.product_category_name_english
ORDER BY item_revenue DESC;


/* ============================================================
   8. SELLER: TOP 10 SELLERS BY BOOKED REVENUE
   Revenue is at item level. An order can contain items from several sellers (1,278 orders do),
   so "orders" here means distinct orders the seller took part in.
   ============================================================ */

SELECT TOP (10)
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT i.order_key)  AS orders,
    SUM(i.price)                 AS item_revenue
FROM dbo.fact_order_items i
INNER JOIN dbo.dim_orders  o ON o.order_key  = i.order_key
INNER JOIN dbo.dim_sellers s ON s.seller_key = i.seller_key
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY s.seller_id, s.seller_city, s.seller_state
ORDER BY item_revenue DESC;


/* ============================================================
   9. GEOGRAPHY: BOOKED REVENUE BY CUSTOMER STATE
   customers = distinct people (customer_unique_id), not customer_id.
   ============================================================ */

SELECT
    c.customer_state,
    COUNT(*)                                              AS booked_orders,
    COUNT(DISTINCT c.customer_unique_id)                  AS customers,
    SUM(r.item_revenue)                                   AS booked_revenue,
    CAST(SUM(r.item_revenue) / COUNT(*) AS DECIMAL(10,2)) AS aov
FROM #order_revenue r
INNER JOIN dbo.dim_customers c ON c.customer_key = r.customer_key
GROUP BY c.customer_state
ORDER BY booked_revenue DESC;


/* ============================================================
   10. PAYMENTS: PAYMENT MIX FOR BOOKED ORDERS
   An order can use several payment types, so orders per type add up to more than the order count.
   ============================================================ */

SELECT
    p.payment_type,
    COUNT(DISTINCT p.order_key)  AS orders,
    SUM(p.payment_value)         AS payment_value,
    CAST(AVG(1.0 * p.payment_installments) AS DECIMAL(4,1)) AS avg_installments
FROM dbo.fact_payments p
INNER JOIN #order_revenue r ON r.order_key = p.order_key
GROUP BY p.payment_type
ORDER BY payment_value DESC;
