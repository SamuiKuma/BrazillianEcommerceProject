/*
    06_powerbi_views.sql
    Layer : REPORTING (what Power BI connects to)
    Run   : after 03_facts.sql. Safe to re-run (CREATE OR ALTER).

    Two views, each with ONE clearly stated grain, so a report cannot accidentally multiply rows:

      vw_order_summary   one row per order   -> order counts, AOV, delivery, reviews
      vw_order_items     one row per item    -> product / seller revenue

    Both use the same booked / realized rules as 05_analysis.sql:
      booked   = has at least one item and status is not 'canceled' / 'unavailable'
      realized = booked and status = 'delivered'
    The views carry keys and measures only; descriptive columns (category, state, month name...) come from
    the dim_ tables in the Power BI model.
*/

USE Brazillian_Ecommerce;
GO

CREATE OR ALTER VIEW dbo.vw_order_items AS
SELECT
    i.order_item_key,
    i.order_key,
    i.product_key,
    i.seller_key,
    o.order_status,
    o.order_purchase_date_key,
    i.price,
    i.freight_value,
    CASE WHEN o.order_status NOT IN ('canceled', 'unavailable') THEN 1 ELSE 0 END                    AS is_booked,
    CASE WHEN o.order_status NOT IN ('canceled', 'unavailable') THEN i.price ELSE 0 END               AS booked_revenue,
    CASE WHEN o.order_status = 'delivered' THEN i.price ELSE 0 END                                    AS realized_revenue
FROM dbo.fact_order_items i
INNER JOIN dbo.dim_orders o ON o.order_key = i.order_key;
GO

CREATE OR ALTER VIEW dbo.vw_order_summary AS
WITH items AS (
    SELECT order_key,
           COUNT(*)            AS item_count,
           SUM(price)          AS item_revenue,
           SUM(freight_value)  AS freight_value
    FROM dbo.fact_order_items
    GROUP BY order_key
),
payments AS (
    SELECT order_key, SUM(payment_value) AS payment_total
    FROM dbo.fact_payments
    GROUP BY order_key
),
latest_review AS (
    -- orders can have several reviews; keep the most recently answered one
    SELECT order_key, review_score
    FROM (
        SELECT order_key, review_score,
               ROW_NUMBER() OVER (PARTITION BY order_key
                                  ORDER BY review_answer_timestamp DESC, review_creation_date DESC, review_key DESC) AS rn
        FROM dbo.fact_reviews
    ) r
    WHERE rn = 1
)
SELECT
    o.order_key,
    o.order_id,
    o.customer_key,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_purchase_date_key,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    COALESCE(i.item_count, 0)      AS item_count,
    COALESCE(i.item_revenue, 0)    AS item_revenue,
    COALESCE(i.freight_value, 0)   AS freight_value,
    COALESCE(p.payment_total, 0)   AS payment_total,
    r.review_score,
    CASE WHEN o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
         THEN DATEDIFF(DAY, o.order_purchase_timestamp, o.order_delivered_customer_date) END      AS days_to_deliver,
    -- NULL when delivery cannot be measured, so AVERAGE(is_late) in Power BI is the late %
    CASE WHEN o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
         THEN CASE WHEN o.order_delivered_customer_date_key > o.order_estimated_delivery_date_key THEN 1 ELSE 0 END END AS is_late,
    CASE WHEN i.order_key IS NOT NULL AND o.order_status NOT IN ('canceled', 'unavailable') THEN 1 ELSE 0 END AS is_booked,
    CASE WHEN i.order_key IS NOT NULL AND o.order_status NOT IN ('canceled', 'unavailable')
         THEN i.item_revenue ELSE 0 END                                                           AS booked_revenue,
    CASE WHEN i.order_key IS NOT NULL AND o.order_status = 'delivered'
         THEN i.item_revenue ELSE 0 END                                                           AS realized_revenue
FROM dbo.dim_orders o
LEFT JOIN items         i ON i.order_key = o.order_key
LEFT JOIN payments      p ON p.order_key = o.order_key
LEFT JOIN latest_review r ON r.order_key = o.order_key;
GO

/* ---------- Checks: the views must reconcile with the tables ---------- */

SELECT
    (SELECT COUNT(*) FROM dbo.vw_order_summary)                                      AS summary_rows,       -- = dim_orders
    (SELECT COUNT(*) FROM dbo.dim_orders)                                            AS dim_orders_rows,
    (SELECT COUNT(*) FROM dbo.vw_order_items)                                        AS item_rows,          -- = fact_order_items
    (SELECT COUNT(*) FROM dbo.fact_order_items)                                      AS fact_item_rows,
    (SELECT SUM(booked_revenue) FROM dbo.vw_order_summary)                           AS booked_rev_summary, -- all three equal
    (SELECT SUM(booked_revenue) FROM dbo.vw_order_items)                             AS booked_rev_items,
    (SELECT SUM(price) FROM dbo.fact_order_items i
       JOIN dbo.dim_orders o ON o.order_key = i.order_key
      WHERE o.order_status NOT IN ('canceled', 'unavailable'))                       AS booked_rev_tables;
