/*
    01_load_raw.sql
    Layer : RAW (landing)
    Run   : first. Re-runnable - the raw tables are dropped and reloaded from the CSV files every time,
            so the CSVs stay the single source of truth.
    Needs : the 9 Olist CSV files in @folder below, readable by the SQL Server service account.

    Raw rules: every column is loaded as text and nothing is cleaned here.
    Type conversion, trimming and NULL handling all happen in 02/03.
*/

IF DB_ID('Brazillian_Ecommerce') IS NULL
    CREATE DATABASE Brazillian_Ecommerce;
GO

USE Brazillian_Ecommerce;
GO

/* ---------- Raw tables ---------- */

DROP TABLE IF EXISTS dbo.raw_olist_customers;
CREATE TABLE dbo.raw_olist_customers (
    customer_id               NVARCHAR(50),
    customer_unique_id        NVARCHAR(50),
    customer_zip_code_prefix  NVARCHAR(50),
    customer_city             NVARCHAR(100),
    customer_state            NVARCHAR(50)
);

DROP TABLE IF EXISTS dbo.raw_olist_geolocation;
CREATE TABLE dbo.raw_olist_geolocation (
    geolocation_zip_code_prefix  NVARCHAR(50),
    geolocation_lat              NVARCHAR(50),
    geolocation_lng              NVARCHAR(50),
    geolocation_city             NVARCHAR(100),
    geolocation_state            NVARCHAR(50)
);

DROP TABLE IF EXISTS dbo.raw_olist_orders;
CREATE TABLE dbo.raw_olist_orders (
    order_id                       NVARCHAR(50),
    customer_id                    NVARCHAR(50),
    order_status                   NVARCHAR(50),
    order_purchase_timestamp       NVARCHAR(50),
    order_approved_at              NVARCHAR(50),
    order_delivered_carrier_date   NVARCHAR(50),
    order_delivered_customer_date  NVARCHAR(50),
    order_estimated_delivery_date  NVARCHAR(50)
);

DROP TABLE IF EXISTS dbo.raw_olist_order_items;
CREATE TABLE dbo.raw_olist_order_items (
    order_id             NVARCHAR(50),
    order_item_id        NVARCHAR(50),
    product_id           NVARCHAR(50),
    seller_id            NVARCHAR(50),
    shipping_limit_date  NVARCHAR(50),
    price                NVARCHAR(50),
    freight_value        NVARCHAR(50)
);

DROP TABLE IF EXISTS dbo.raw_olist_order_payments;
CREATE TABLE dbo.raw_olist_order_payments (
    order_id              NVARCHAR(50),
    payment_sequential    NVARCHAR(50),
    payment_type          NVARCHAR(50),
    payment_installments  NVARCHAR(50),
    payment_value         NVARCHAR(50)
);

DROP TABLE IF EXISTS dbo.raw_olist_order_reviews;
CREATE TABLE dbo.raw_olist_order_reviews (
    review_id                NVARCHAR(50),
    order_id                 NVARCHAR(50),
    review_score             NVARCHAR(50),
    review_comment_title     NVARCHAR(255),
    review_comment_message   NVARCHAR(1000),
    review_creation_date     NVARCHAR(50),
    review_answer_timestamp  NVARCHAR(50)
);

-- "lenght" is misspelled in the source files; kept as-is in raw and corrected in dim_products
DROP TABLE IF EXISTS dbo.raw_olist_products;
CREATE TABLE dbo.raw_olist_products (
    product_id                   NVARCHAR(50),
    product_category_name        NVARCHAR(100),
    product_name_lenght          NVARCHAR(50),
    product_description_lenght   NVARCHAR(50),
    product_photos_qty           NVARCHAR(50),
    product_weight_g             NVARCHAR(50),
    product_length_cm            NVARCHAR(50),
    product_height_cm            NVARCHAR(50),
    product_width_cm             NVARCHAR(50)
);

DROP TABLE IF EXISTS dbo.raw_olist_sellers;
CREATE TABLE dbo.raw_olist_sellers (
    seller_id                NVARCHAR(50),
    seller_zip_code_prefix   NVARCHAR(50),
    seller_city              NVARCHAR(100),
    seller_state             NVARCHAR(50)
);

DROP TABLE IF EXISTS dbo.raw_product_category_translation;
CREATE TABLE dbo.raw_product_category_translation (
    product_category_name          NVARCHAR(100),
    product_category_name_english  NVARCHAR(100)
);
GO

/* ---------- Load ---------- */

-- Options used on every load:
--   FORMAT = 'CSV'      understands quoted fields, so the " characters are not stored in the data
--   CODEPAGE = '65001'  reads the file as UTF-8 so accents survive (sao paulo, not sÃ£o paulo)
--   FIRSTROW = 2        skips the header row
--   ROWTERMINATOR       0x0a = line feed (LF), 0x0d0a = carriage return + line feed (CRLF).
--                       The files do not all use the same one, so it is set per file.
--   TABLOCK             locks the table during the load, which makes it faster
-- If the CSVs live somewhere else, change the folder in each path below.

BULK INSERT dbo.raw_olist_customers
FROM 'C:\Brazillian E-Commerce SQL Project\olist_customers_dataset.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT dbo.raw_olist_geolocation
FROM 'C:\Brazillian E-Commerce SQL Project\olist_geolocation_dataset.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT dbo.raw_olist_orders
FROM 'C:\Brazillian E-Commerce SQL Project\olist_orders_dataset.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT dbo.raw_olist_order_items
FROM 'C:\Brazillian E-Commerce SQL Project\olist_order_items_dataset.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT dbo.raw_olist_order_payments
FROM 'C:\Brazillian E-Commerce SQL Project\olist_order_payments_dataset.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

-- reviews: CRLF line endings (and some comments contain line breaks inside quotes, which FORMAT = 'CSV' handles)
BULK INSERT dbo.raw_olist_order_reviews
FROM 'C:\Brazillian E-Commerce SQL Project\olist_order_reviews_dataset.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0d0a', TABLOCK);

BULK INSERT dbo.raw_olist_products
FROM 'C:\Brazillian E-Commerce SQL Project\olist_products_dataset.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT dbo.raw_olist_sellers
FROM 'C:\Brazillian E-Commerce SQL Project\olist_sellers_dataset.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0a', TABLOCK);

BULK INSERT dbo.raw_product_category_translation
FROM 'C:\Brazillian E-Commerce SQL Project\product_category_name_translation.csv'
WITH (FORMAT = 'CSV', FIELDQUOTE = '"', FIRSTROW = 2, CODEPAGE = '65001', ROWTERMINATOR = '0x0d0a', TABLOCK);
GO

/* ---------- Quick sanity check: expected row counts for the standard Olist download ---------- */

SELECT 'raw_olist_customers' AS raw_table,      COUNT(*) AS row_count, 99441   AS expected FROM dbo.raw_olist_customers
UNION ALL SELECT 'raw_olist_geolocation',            COUNT(*), 1000163 FROM dbo.raw_olist_geolocation
UNION ALL SELECT 'raw_olist_orders',                 COUNT(*), 99441   FROM dbo.raw_olist_orders
UNION ALL SELECT 'raw_olist_order_items',            COUNT(*), 112650  FROM dbo.raw_olist_order_items
UNION ALL SELECT 'raw_olist_order_payments',         COUNT(*), 103886  FROM dbo.raw_olist_order_payments
UNION ALL SELECT 'raw_olist_order_reviews',          COUNT(*), 99224   FROM dbo.raw_olist_order_reviews
UNION ALL SELECT 'raw_olist_products',               COUNT(*), 32951   FROM dbo.raw_olist_products
UNION ALL SELECT 'raw_olist_sellers',                COUNT(*), 3095    FROM dbo.raw_olist_sellers
UNION ALL SELECT 'raw_product_category_translation', COUNT(*), 71      FROM dbo.raw_product_category_translation;
