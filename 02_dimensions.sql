/*
    02_dimensions.sql
    Layer : DIMENSIONS (cleaned, typed, one row per business entity)
    Run   : second, after 01_load_raw.sql. Re-runnable - the derived tables are rebuilt from the raw tables.

    Grain of each table
      dim_date         one row per calendar day
      dim_geolocation  one row per zip prefix (average of the usable lat/lng points)
      dim_customers    one row per customer_id  (NOT per person: Olist issues a new customer_id for every order,
                       so count people with COUNT(DISTINCT customer_unique_id))
      dim_sellers      one row per seller_id
      dim_products     one row per product_id
      dim_orders       one row per order_id. Holds status + timestamps, so it behaves like an order header /
                       fact table even though the name says dim.
*/

USE Brazillian_Ecommerce;
GO

/* ---------- Rebuild: drop facts first because they reference the dimensions ---------- */

DROP TABLE IF EXISTS dbo.fact_reviews;
DROP TABLE IF EXISTS dbo.fact_payments;
DROP TABLE IF EXISTS dbo.fact_order_items;
DROP TABLE IF EXISTS dbo.dim_orders;
DROP TABLE IF EXISTS dbo.dim_products;
DROP TABLE IF EXISTS dbo.dim_sellers;
DROP TABLE IF EXISTS dbo.dim_customers;
DROP TABLE IF EXISTS dbo.dim_geolocation;
DROP TABLE IF EXISTS dbo.dim_date;
GO

/* ---------- dim_date ---------- */
-- Order dates stop in 2018, but shipping_limit_date goes out to 2020, so the range runs to the end of 2020.
-- date_key is yyyymmdd. Weekday maths avoids DATEFIRST / language settings so the result is the same on any server.

CREATE TABLE dbo.dim_date (
    date_key     INT          NOT NULL PRIMARY KEY,
    date_value   DATE         NOT NULL,
    year         INT          NOT NULL,
    quarter      INT          NOT NULL,
    month        INT          NOT NULL,
    month_name   NVARCHAR(20) NOT NULL,
    day          INT          NOT NULL,
    day_of_week  INT          NOT NULL,   -- 1 = Monday ... 7 = Sunday
    day_name     NVARCHAR(20) NOT NULL,
    is_weekend   BIT          NOT NULL
);

DECLARE @date_from DATE = '2016-01-01';
DECLARE @date_to   DATE = '2020-12-31';

WITH numbers AS (
    SELECT TOP (DATEDIFF(DAY, @date_from, @date_to) + 1)
           ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
),
calendar AS (
    SELECT DATEADD(DAY, n, @date_from) AS dt FROM numbers
)
INSERT INTO dbo.dim_date (date_key, date_value, year, quarter, month, month_name, day, day_of_week, day_name, is_weekend)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), dt, 112)),
    dt,
    DATEPART(YEAR, dt),
    DATEPART(QUARTER, dt),
    DATEPART(MONTH, dt),
    FORMAT(dt, 'MMMM', 'en-US'),
    DATEPART(DAY, dt),
    DATEDIFF(DAY, '19000101', dt) % 7 + 1,           -- 1900-01-01 was a Monday
    FORMAT(dt, 'dddd', 'en-US'),
    CASE WHEN DATEDIFF(DAY, '19000101', dt) % 7 >= 5 THEN 1 ELSE 0 END
FROM calendar;
GO

/* ---------- dim_geolocation ---------- */
-- The raw file has ~1M rows for ~19k zip prefixes (many GPS points per zip).
-- Collapse to one row per zip with the average position so joins to customers/sellers cannot multiply rows.
-- Points outside Brazil's bounding box are bad GPS data (the raw file has points at lat +45 / lng +121),
-- so they are excluded before averaging. City names are not kept: the same zip appears with several spellings.

CREATE TABLE dbo.dim_geolocation (
    geolocation_zip_code_prefix  VARCHAR(10)   NOT NULL PRIMARY KEY,
    geolocation_lat              DECIMAL(9,6)  NOT NULL,
    geolocation_lng              DECIMAL(9,6)  NOT NULL
);

INSERT INTO dbo.dim_geolocation (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng)
SELECT
    TRIM(geolocation_zip_code_prefix),
    AVG(TRY_CAST(geolocation_lat AS FLOAT)),
    AVG(TRY_CAST(geolocation_lng AS FLOAT))
FROM dbo.raw_olist_geolocation
WHERE TRY_CAST(geolocation_lat AS FLOAT) BETWEEN -34 AND 6
  AND TRY_CAST(geolocation_lng AS FLOAT) BETWEEN -74 AND -34
GROUP BY TRIM(geolocation_zip_code_prefix);
GO

/* ---------- dim_customers ---------- */

CREATE TABLE dbo.dim_customers (
    customer_key              INT IDENTITY PRIMARY KEY,
    customer_id               VARCHAR(50)   NOT NULL UNIQUE,
    customer_unique_id        VARCHAR(50)   NOT NULL,
    customer_zip_code_prefix  VARCHAR(10),
    customer_city             NVARCHAR(100),
    customer_state            VARCHAR(2),
    customer_lat              DECIMAL(9,6),
    customer_lng              DECIMAL(9,6)
);

INSERT INTO dbo.dim_customers (customer_id, customer_unique_id, customer_zip_code_prefix,
                               customer_city, customer_state, customer_lat, customer_lng)
SELECT
    TRIM(c.customer_id),
    TRIM(c.customer_unique_id),
    TRIM(c.customer_zip_code_prefix),
    NULLIF(TRIM(c.customer_city), ''),
    UPPER(NULLIF(TRIM(c.customer_state), '')),
    g.geolocation_lat,
    g.geolocation_lng
FROM dbo.raw_olist_customers c
LEFT JOIN dbo.dim_geolocation g ON TRIM(c.customer_zip_code_prefix) = g.geolocation_zip_code_prefix;
GO

/* ---------- dim_sellers ---------- */

CREATE TABLE dbo.dim_sellers (
    seller_key              INT IDENTITY PRIMARY KEY,
    seller_id               VARCHAR(50)   NOT NULL UNIQUE,
    seller_zip_code_prefix  VARCHAR(10),
    seller_city             NVARCHAR(100),
    seller_state            VARCHAR(2),
    seller_lat              DECIMAL(9,6),
    seller_lng              DECIMAL(9,6)
);

INSERT INTO dbo.dim_sellers (seller_id, seller_zip_code_prefix, seller_city, seller_state, seller_lat, seller_lng)
SELECT
    TRIM(s.seller_id),
    TRIM(s.seller_zip_code_prefix),
    NULLIF(TRIM(s.seller_city), ''),
    UPPER(NULLIF(TRIM(s.seller_state), '')),
    g.geolocation_lat,
    g.geolocation_lng
FROM dbo.raw_olist_sellers s
LEFT JOIN dbo.dim_geolocation g ON TRIM(s.seller_zip_code_prefix) = g.geolocation_zip_code_prefix;
GO

/* ---------- dim_products ---------- */
-- 610 products have no category in the source. They stay NULL in product_category_name (we do not guess)
-- and show up as 'unknown' in the English column so reports do not drop them.
-- Two categories are missing from the translation file; they fall back to the Portuguese name.

CREATE TABLE dbo.dim_products (
    product_key                    INT IDENTITY PRIMARY KEY,
    product_id                     VARCHAR(50)   NOT NULL UNIQUE,
    product_category_name          NVARCHAR(100),
    product_category_name_english  NVARCHAR(100),
    product_name_length            INT,
    product_description_length     INT,
    product_photos_qty             INT,
    product_weight_g               INT,
    product_length_cm              INT,
    product_height_cm              INT,
    product_width_cm               INT
);

INSERT INTO dbo.dim_products (product_id, product_category_name, product_category_name_english,
                              product_name_length, product_description_length, product_photos_qty,
                              product_weight_g, product_length_cm, product_height_cm, product_width_cm)
SELECT
    TRIM(p.product_id),
    NULLIF(TRIM(p.product_category_name), ''),
    COALESCE(NULLIF(TRIM(t.product_category_name_english), ''), NULLIF(TRIM(p.product_category_name), ''), 'unknown'),
    TRY_CAST(NULLIF(TRIM(p.product_name_lenght), '') AS INT),
    TRY_CAST(NULLIF(TRIM(p.product_description_lenght), '') AS INT),
    TRY_CAST(NULLIF(TRIM(p.product_photos_qty), '') AS INT),
    TRY_CAST(NULLIF(TRIM(p.product_weight_g), '') AS INT),
    TRY_CAST(NULLIF(TRIM(p.product_length_cm), '') AS INT),
    TRY_CAST(NULLIF(TRIM(p.product_height_cm), '') AS INT),
    TRY_CAST(NULLIF(TRIM(p.product_width_cm), '') AS INT)
FROM dbo.raw_olist_products p
LEFT JOIN dbo.raw_product_category_translation t
       ON TRIM(p.product_category_name) = TRIM(t.product_category_name);
GO

/* ---------- dim_orders ---------- */
-- Dates are converted once in the CTE. The *_key columns are built directly from the timestamp (yyyymmdd),
-- so a date outside dim_date makes the insert fail on the foreign key instead of silently becoming NULL.
-- Missing approval / delivery dates are legitimate (cancelled or not yet delivered orders) and stay NULL.

CREATE TABLE dbo.dim_orders (
    order_key                         INT IDENTITY PRIMARY KEY,
    order_id                          VARCHAR(50)  NOT NULL UNIQUE,
    customer_key                      INT          NOT NULL FOREIGN KEY REFERENCES dbo.dim_customers(customer_key),
    order_status                      VARCHAR(50)  NOT NULL,
    order_purchase_timestamp          DATETIME2(0),
    order_purchase_date_key           INT FOREIGN KEY REFERENCES dbo.dim_date(date_key),
    order_approved_date               DATETIME2(0),
    order_approved_date_key           INT FOREIGN KEY REFERENCES dbo.dim_date(date_key),
    order_delivered_carrier_date      DATETIME2(0),
    order_delivered_carrier_date_key  INT FOREIGN KEY REFERENCES dbo.dim_date(date_key),
    order_delivered_customer_date     DATETIME2(0),
    order_delivered_customer_date_key INT FOREIGN KEY REFERENCES dbo.dim_date(date_key),
    order_estimated_delivery_date     DATETIME2(0),
    order_estimated_delivery_date_key INT FOREIGN KEY REFERENCES dbo.dim_date(date_key)
);

WITH typed_orders AS (
    SELECT
        TRIM(order_id)                                                                  AS order_id,
        TRIM(customer_id)                                                               AS customer_id,
        LOWER(TRIM(order_status))                                                       AS order_status,
        TRY_CAST(NULLIF(TRIM(order_purchase_timestamp), '')      AS DATETIME2(0))       AS purchase_ts,
        TRY_CAST(NULLIF(TRIM(order_approved_at), '')             AS DATETIME2(0))       AS approved_ts,
        TRY_CAST(NULLIF(TRIM(order_delivered_carrier_date), '')  AS DATETIME2(0))       AS carrier_ts,
        TRY_CAST(NULLIF(TRIM(order_delivered_customer_date), '') AS DATETIME2(0))       AS customer_ts,
        TRY_CAST(NULLIF(TRIM(order_estimated_delivery_date), '') AS DATETIME2(0))       AS estimated_ts
    FROM dbo.raw_olist_orders
)
INSERT INTO dbo.dim_orders (
    order_id, customer_key, order_status,
    order_purchase_timestamp,          order_purchase_date_key,
    order_approved_date,               order_approved_date_key,
    order_delivered_carrier_date,      order_delivered_carrier_date_key,
    order_delivered_customer_date,     order_delivered_customer_date_key,
    order_estimated_delivery_date,     order_estimated_delivery_date_key)
SELECT
    o.order_id, c.customer_key, o.order_status,
    o.purchase_ts,   CONVERT(INT, CONVERT(CHAR(8), o.purchase_ts, 112)),
    o.approved_ts,   CONVERT(INT, CONVERT(CHAR(8), o.approved_ts, 112)),
    o.carrier_ts,    CONVERT(INT, CONVERT(CHAR(8), o.carrier_ts, 112)),
    o.customer_ts,   CONVERT(INT, CONVERT(CHAR(8), o.customer_ts, 112)),
    o.estimated_ts,  CONVERT(INT, CONVERT(CHAR(8), o.estimated_ts, 112))
FROM typed_orders o
INNER JOIN dbo.dim_customers c ON o.customer_id = c.customer_id;
GO

/* ---------- Quick look ---------- */

SELECT 'dim_date' AS table_name, COUNT(*) AS row_count FROM dbo.dim_date
UNION ALL SELECT 'dim_geolocation', COUNT(*) FROM dbo.dim_geolocation
UNION ALL SELECT 'dim_customers',   COUNT(*) FROM dbo.dim_customers
UNION ALL SELECT 'dim_sellers',     COUNT(*) FROM dbo.dim_sellers
UNION ALL SELECT 'dim_products',    COUNT(*) FROM dbo.dim_products
UNION ALL SELECT 'dim_orders',      COUNT(*) FROM dbo.dim_orders;
