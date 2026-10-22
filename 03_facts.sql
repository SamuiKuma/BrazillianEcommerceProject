/*
    03_facts.sql
    Layer : FACTS (transactional tables, linked to the dimensions by surrogate keys)
    Run   : third, after 02_dimensions.sql. Re-runnable - the fact tables are rebuilt from raw.

    Grain of each table
      fact_order_items  one row per item in an order           -> unique on (order_key, order_item_id)
      fact_payments     one row per payment on an order        -> unique on (order_key, payment_sequential)
                        (an order can be paid with several methods, e.g. card + voucher)
      fact_reviews      one row per review                     -> unique on (review_id, order_key)
                        review_id alone is NOT unique (the same review_id appears on several orders), and an order
                        can have more than one review. Never join this table to order-level revenue without
                        collapsing it to one row per order first (see vw_order_summary in 06).

    Money columns are different things and are not interchangeable:
      price          item price, excluding freight
      freight_value  shipping charged for that item
      payment_value  what the customer actually paid on the order (can include vouchers / installment interest)
*/

USE Brazillian_Ecommerce;
GO

DROP TABLE IF EXISTS dbo.fact_reviews;
DROP TABLE IF EXISTS dbo.fact_payments;
DROP TABLE IF EXISTS dbo.fact_order_items;
GO

/* ---------- fact_order_items ---------- */
-- price / freight_value are NOT NULL on purpose: a value that fails TRY_CAST makes the load fail loudly
-- instead of quietly turning into NULL and disappearing from revenue.

CREATE TABLE dbo.fact_order_items (
    order_item_key        INT IDENTITY PRIMARY KEY,
    order_item_id         INT           NOT NULL,
    order_key             INT           NOT NULL FOREIGN KEY REFERENCES dbo.dim_orders(order_key),
    product_key           INT           NOT NULL FOREIGN KEY REFERENCES dbo.dim_products(product_key),
    seller_key            INT           NOT NULL FOREIGN KEY REFERENCES dbo.dim_sellers(seller_key),
    shipping_limit_date   DATETIME2(0),
    shipping_limit_date_key INT FOREIGN KEY REFERENCES dbo.dim_date(date_key),
    price                 DECIMAL(18,2) NOT NULL,
    freight_value         DECIMAL(18,2) NOT NULL,
    CONSTRAINT uq_fact_order_items_order_item UNIQUE (order_key, order_item_id)
);

WITH typed_items AS (
    SELECT
        TRIM(order_id)    AS order_id,
        TRIM(product_id)  AS product_id,
        TRIM(seller_id)   AS seller_id,
        TRY_CAST(NULLIF(TRIM(order_item_id), '')       AS INT)           AS order_item_id,
        TRY_CAST(NULLIF(TRIM(shipping_limit_date), '') AS DATETIME2(0))  AS shipping_limit_ts,
        TRY_CAST(NULLIF(TRIM(price), '')               AS DECIMAL(18,2)) AS price,
        TRY_CAST(NULLIF(TRIM(freight_value), '')       AS DECIMAL(18,2)) AS freight_value
    FROM dbo.raw_olist_order_items
)
INSERT INTO dbo.fact_order_items (
    order_item_id, order_key, product_key, seller_key,
    shipping_limit_date, shipping_limit_date_key, price, freight_value)
SELECT
    i.order_item_id, o.order_key, p.product_key, s.seller_key,
    i.shipping_limit_ts, CONVERT(INT, CONVERT(CHAR(8), i.shipping_limit_ts, 112)),
    i.price, i.freight_value
FROM typed_items i
INNER JOIN dbo.dim_orders   o ON i.order_id   = o.order_id
INNER JOIN dbo.dim_products p ON i.product_id = p.product_id
INNER JOIN dbo.dim_sellers  s ON i.seller_id  = s.seller_id;
GO

/* ---------- fact_payments ---------- */

CREATE TABLE dbo.fact_payments (
    payment_key           INT IDENTITY,
    order_key             INT           NOT NULL FOREIGN KEY REFERENCES dbo.dim_orders(order_key),
    payment_sequential    INT           NOT NULL,
    payment_type          VARCHAR(50),
    payment_installments  INT,
    payment_value         DECIMAL(18,2) NOT NULL,
    PRIMARY KEY (order_key, payment_sequential)
);

INSERT INTO dbo.fact_payments (order_key, payment_sequential, payment_type, payment_installments, payment_value)
SELECT
    o.order_key,
    TRY_CAST(NULLIF(TRIM(p.payment_sequential), '')   AS INT),
    NULLIF(LOWER(TRIM(p.payment_type)), ''),
    TRY_CAST(NULLIF(TRIM(p.payment_installments), '') AS INT),
    TRY_CAST(NULLIF(TRIM(p.payment_value), '')        AS DECIMAL(18,2))
FROM dbo.raw_olist_order_payments p
INNER JOIN dbo.dim_orders o ON TRIM(p.order_id) = o.order_id;
GO

/* ---------- fact_reviews ---------- */
-- All 99,224 review rows are kept. Choosing one review per order is an analysis decision, made in the views.

CREATE TABLE dbo.fact_reviews (
    review_key                   INT IDENTITY PRIMARY KEY,
    review_id                    VARCHAR(50)    NOT NULL,
    order_key                    INT            NOT NULL FOREIGN KEY REFERENCES dbo.dim_orders(order_key),
    review_score                 INT            NOT NULL,
    review_comment_title         NVARCHAR(255),
    review_comment_message       NVARCHAR(1000),
    review_creation_date         DATETIME2(0),
    review_creation_key          INT FOREIGN KEY REFERENCES dbo.dim_date(date_key),
    review_answer_timestamp      DATETIME2(0),
    review_answer_timestamp_key  INT FOREIGN KEY REFERENCES dbo.dim_date(date_key),
    CONSTRAINT uq_fact_reviews_review_order UNIQUE (review_id, order_key)
);

WITH typed_reviews AS (
    SELECT
        TRIM(review_id)  AS review_id,
        TRIM(order_id)   AS order_id,
        TRY_CAST(NULLIF(TRIM(review_score), '')            AS INT)          AS review_score,
        NULLIF(TRIM(review_comment_title), '')                              AS review_comment_title,
        NULLIF(TRIM(review_comment_message), '')                            AS review_comment_message,
        TRY_CAST(NULLIF(TRIM(review_creation_date), '')    AS DATETIME2(0)) AS creation_ts,
        TRY_CAST(NULLIF(TRIM(review_answer_timestamp), '') AS DATETIME2(0)) AS answer_ts
    FROM dbo.raw_olist_order_reviews
)
INSERT INTO dbo.fact_reviews (
    review_id, order_key, review_score, review_comment_title, review_comment_message,
    review_creation_date, review_creation_key, review_answer_timestamp, review_answer_timestamp_key)
SELECT
    r.review_id, o.order_key, r.review_score, r.review_comment_title, r.review_comment_message,
    r.creation_ts, CONVERT(INT, CONVERT(CHAR(8), r.creation_ts, 112)),
    r.answer_ts,   CONVERT(INT, CONVERT(CHAR(8), r.answer_ts, 112))
FROM typed_reviews r
INNER JOIN dbo.dim_orders o ON r.order_id = o.order_id;
GO

/* ---------- Quick look ---------- */

SELECT 'fact_order_items' AS table_name, COUNT(*) AS row_count FROM dbo.fact_order_items
UNION ALL SELECT 'fact_payments', COUNT(*) FROM dbo.fact_payments
UNION ALL SELECT 'fact_reviews',  COUNT(*) FROM dbo.fact_reviews;
