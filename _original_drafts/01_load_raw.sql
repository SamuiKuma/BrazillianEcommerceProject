CREATE TABLE dbo.raw_olist_customers(
customer_id NVARCHAR(50),customer_unique_id NVARCHAR(50), customer_zip_code_prefix NVARCHAR(50), customer_city NVARCHAR(50), customer_state NVARCHAR (50)
)

CREATE TABLE dbo.raw_olist_order_reviews_dataset(
review_id VARCHAR(50), order_id VARCHAR(50), review_score VARCHAR(50), 
review_comment_title NVARCHAR (255),review_comment_message NVARCHAR (520), 
review_creation_date VARCHAR(50), review_answer_timestamp VARCHAR(50) 
)

CREATE TABLE dbo.raw_olist_sellers(
seller_id VARCHAR(50), seller_zip_code_prefix VARCHAR(50), seller_city VARCHAR(50), seller_state VARCHAR(50)
)


BULK INSERT dbo.raw_olist_order_reviews_dataset 
FROM 'C:\Brazillian E-Commerce SQL Project\olist_order_reviews_dataset.csv'
WITH (
FIRSTROW = 2,
FORMAT = 'CSV',
FIELDTERMINATOR = ',',
ROWTERMINATOR = '0x0d0a',
TABLOCK
)

	
USE Brazillian_Ecommerce


SELECT * FROM raw_olist_order_reviews_dataset

DROP TABLE dbo.raw_olist_order_reviews_dataset 