/* Late Delivery % */

WITH deliveredOrders AS(
SELECT COUNT(*) AS deliveredOrderCount
FROM dim_orders
where order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
),
lateOrders AS(
SELECT COUNT(*) AS lateOrderCount
FROM dim_orders
where order_status = 'delivered' AND order_delivered_customer_date_key > order_estimated_delivery_date_key
),
lateDelivery AS(
SELECT deliveredOrderCount,lateOrderCount,(lateOrderCount*1.0/deliveredOrderCount) as lateDeliveryCount
FROM deliveredOrders,lateOrders
)
SELECT deliveredOrderCount,lateOrderCount,lateDeliveryCount
FROM lateDelivery


/* Review Average */

/* AOV */

/* Booked Orders with Revenue */

/* Booked Revenue and Realized Revenue */

/* Booked Revenue Orders Count */