# Brazilian E-Commerce SQL Pipeline and Power BI Dashboard

A SQL Server pipeline and Power BI dashboard built on the Olist Brazilian e-commerce dataset (about 100k orders, 2016 to 2018).

## What it does

Raw CSV files are loaded into SQL Server, cleaned and typed into dimension and fact tables, checked for quality, and exposed as views for Power BI.

```
CSV files --> raw text tables (01) --> dimensions (02) --> facts (03)
                                              |
                                              +--> data checks (04)
                                              +--> analysis queries (05)
                                              +--> Power BI views (06) --> Power BI dashboard
```

## Run order

Run the scripts in this order against SQL Server (tested on SQL Server 2025 Express):

| Script | Purpose |
|---|---|
| `01_load_raw.sql` | Creates 9 raw text tables and loads the CSVs with `BULK INSERT` |
| `02_dimensions.sql` | Builds `dim_date`, `dim_geolocation`, `dim_customers`, `dim_sellers`, `dim_products`, `dim_orders` |
| `03_facts.sql` | Builds `fact_order_items`, `fact_payments`, `fact_reviews` |
| `04_checks.sql` | Returns one PASS / FAIL / WARN result set covering keys, row counts, reconciliation and source data |
| `05_analysis.sql` | Business metrics and the questions behind the dashboard |
| `06_powerbi_views.sql` | Creates `vw_order_items` and `vw_order_summary` for Power BI |

Before running `01_load_raw.sql`, put the CSV files in `C:\Brazillian E-Commerce SQL Project\`, or edit the paths in the script. The SQL Server service account must be able to read that folder.

The original drafts of scripts 01 to 05 are in `_original_drafts/` for comparison.

## Metric definitions

- **Booked order:** an order with at least one item whose status is not `canceled` or `unavailable`.
- **Booked revenue:** sum of item `price`. Freight is excluded and reported separately.
- **Realized revenue:** booked revenue for orders with status `delivered`. The data has no refund or return records, so this is a limit.
- **Average order value (AOV):** booked revenue divided by booked orders.
- **Late delivery:** delivered date is after the estimated delivery date, compared by calendar date. Orders without a delivery date are excluded.

## Key results

These are from the scratch run and match the live database.

| Metric | Value |
|---|---|
| Booked orders | 98,199 |
| Booked revenue (price only) | 13,494,400.74 |
| Realized revenue | 13,221,498.11 (97.98% of booked) |
| Booked freight | 2,241,126.29 |
| AOV excluding freight | 137.42 |
| AOV including freight | 160.24 |
| Late deliveries | 6.77% (6,534 of 96,470 delivered) |

## Data issues found

The checks report these rather than correcting them:

- 166 orders have a carrier pickup before the purchase date.
- 23 orders have a customer delivery before the carrier pickup.
- 775 orders have payments but no items.
- 303 orders have payment totals that don't match items plus freight.
- 610 products have no category, and two categories have no English translation.
- 547 orders have more than one review. The analysis keeps one review per order, the latest.

## Power BI dashboard

The dashboard is in [BrazillianEcommerceUpdated.pbix](BrazillianEcommerceUpdated.pbix). It uses the measures above.

**Monthly trends:** booked vs realized revenue, booked order count, and late delivery %.

![Monthly trends](images/Graph%202.png)

**Headline KPIs:** average order value, average review score, booked orders, and booked freight.

![Headline KPIs](images/Graph%201.png)

## Notes

- The repo has no source CSVs. Download the Olist dataset separately.
- The scripts were tested on a scratch database first, then run on the main `Brazillian_Ecommerce` database.
