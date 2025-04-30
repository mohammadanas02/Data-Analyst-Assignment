


-- 1. These queries will provide a foundational understanding of your order fulfillment pipeline and customer payment preferences. 
SELECT order_status, COUNT(*) as status_count 
FROM customer_orders 
GROUP BY order_status 
ORDER BY status_count DESC; 


SELECT payment_method, COUNT(*) as method_count 
FROM payments 
GROUP BY payment_method 
ORDER BY method_count DESC; 

-- ###############################################################################################################################################

-- 2. This query reveals how quickly orders move through your fulfillment pipeline, highlighting potential bottlenecks or efficiencies. 

SELECT  
    order_status, 
    AVG(JULIANDAY(payment_date) - JULIANDAY(order_date)) AS avg_days_to_payment 
FROM customer_orders c 
JOIN payments p ON c.order_id = p.order_id 
WHERE payment_status = 'completed' 
GROUP BY order_status 
ORDER BY avg_days_to_payment;

-- ###############################################################################################################################################

-- 3. This provides a clear view of monthly performance, showing order volume, revenue, and average order value trends. 

SELECT  
    strftime('%Y-%m', order_date) AS month, 
    COUNT(DISTINCT c.order_id) AS order_count, 
    SUM(order_amount) AS total_revenue, 
    SUM(order_amount)/COUNT(DISTINCT c.order_id) AS average_order_value 
FROM customer_orders c 
JOIN payments p ON c.order_id = p.order_id 
WHERE payment_status = 'completed' 
GROUP BY month 
ORDER BY month;

-- ###############################################################################################################################################

-- 4. This query tracks how your order status distribution evolves over time, helping identify seasonal patterns or operational changes.

SELECT  
    strftime('%Y-%m', order_date) AS month, 
    order_status, 
    COUNT(*) AS status_count, 
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY 
strftime('%Y-%m', order_date)), 2) AS status_percentage 
FROM customer_orders 
GROUP BY month, order_status 
ORDER BY month, status_count DESC; 

-- ###############################################################################################################################################

-- 5. This SQL query calculates the average number of days it takes to deliver an order for each month — effectively measuring order fulfillment efficiency over time.

SELECT  
    strftime('%Y-%m', order_date) AS month, 
    AVG(CASE WHEN order_status = 'delivered'  
        THEN JULIANDAY(payment_date) - JULIANDAY(order_date) END) AS avg_days_to_delivery 
FROM customer_orders c 
JOIN payments p ON c.order_id = p.order_id 
WHERE order_status = 'delivered' 
GROUP BY month 
ORDER BY month;
