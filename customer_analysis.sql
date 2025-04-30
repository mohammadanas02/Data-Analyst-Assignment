-- 1. This query identifies your repeat customers and calculates their purchase frequency. For example, a customer with a monthly_purchase_frequency of 2.5 places an average of 2-3 orders per month, indicating high engagement.

SELECT 
    customer_id,
    COUNT(*) AS total_orders,
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    JULIANDAY(MAX(order_date)) - JULIANDAY(MIN(order_date)) AS customer_lifespan_days,
    COUNT(*) / (CASE 
                  WHEN JULIANDAY(MAX(order_date)) - JULIANDAY(MIN(order_date)) = 0 
                  THEN 1 
                  ELSE (JULIANDAY(MAX(order_date)) - JULIANDAY(MIN(order_date)))/30.0 
                END) AS monthly_purchase_frequency
FROM customer_orders
GROUP BY customer_id
ORDER BY total_orders DESC;

-- #####################################################################################################################################################################################################

-- 2. This RFM analysis creates meaningful customer segments based on:
-- Recency: How recently a customer made a purchase
-- Frequency: How often they purchase
-- Monetary: How much they spend

-- For example, "Champions" are your best customers who bought recently, buy often, and spend the most. "At Risk Customers" haven't purchased recently but were previously active.

WITH rfm_data AS (
    SELECT 
        customer_id,
        JULIANDAY('now') - JULIANDAY(MAX(order_date)) AS recency_days,
        COUNT(*) AS frequency,
        SUM(order_amount) AS monetary
    FROM customer_orders
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT 
        customer_id,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
        NTILE(5) OVER (ORDER BY frequency) AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary) AS monetary_score
    FROM rfm_data
)
SELECT 
    customer_id,
    recency_score,
    frequency_score,
    monetary_score,
    recency_score + frequency_score + monetary_score AS total_rfm_score,
    CASE 
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Champions'
        WHEN recency_score >= 3 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'Loyal Customers'
        WHEN recency_score >= 3 AND frequency_score >= 1 AND monetary_score >= 2 THEN 'Potential Loyalists'
        WHEN recency_score >= 4 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'New Customers'
        WHEN recency_score <= 2 AND frequency_score >= 3 AND monetary_score >= 3 THEN 'At Risk Customers'
        WHEN recency_score <= 2 AND frequency_score >= 2 AND monetary_score >= 2 THEN 'Need Attention'
        WHEN recency_score <= 1 AND frequency_score >= 4 AND monetary_score >= 4 THEN 'Cannot Lose Them'
        WHEN recency_score <= 1 AND frequency_score <= 2 AND monetary_score <= 2 THEN 'Lost Customers'
        ELSE 'Others'
    END AS customer_segment
FROM rfm_scores
ORDER BY total_rfm_score DESC;

-- #####################################################################################################################################################################################################

-- 3. This tracks how your customer activity evolves monthly, showing if your customer base is growing and how their purchasing behaviors change seasonally.
-- Monthly customer activity trends
SELECT 
    strftime('%Y-%m', order_date) AS month,
    COUNT(DISTINCT customer_id) AS active_customers,
    COUNT(*) AS total_orders,
    COUNT(*) / COUNT(DISTINCT customer_id) AS orders_per_customer,
    SUM(order_amount) AS total_revenue,
    SUM(order_amount) / COUNT(*) AS average_order_value,
    SUM(order_amount) / COUNT(DISTINCT customer_id) AS revenue_per_customer
FROM customer_orders
GROUP BY month
ORDER BY month;

-- #####################################################################################################################################################################################################


-- 4. This analysis helps identify purchasing cycles. For example, customers who order every 30 days might be good candidates for subscription offerings.
-- Average days between orders by customer
WITH order_dates AS (
    SELECT 
        customer_id,
        order_date,
        LAG(order_date) OVER (PARTITION BY customer_id ORDER BY order_date) AS previous_order_date
    FROM customer_orders
)
SELECT 
    customer_id,
    AVG(JULIANDAY(order_date) - JULIANDAY(previous_order_date)) AS avg_days_between_orders,
    MIN(JULIANDAY(order_date) - JULIANDAY(previous_order_date)) AS min_days_between_orders,
    MAX(JULIANDAY(order_date) - JULIANDAY(previous_order_date)) AS max_days_between_orders,
    COUNT(*) AS total_orders
FROM order_dates
WHERE previous_order_date IS NOT NULL
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY avg_days_between_orders;

-- #####################################################################################################################################################################################################
 
-- 5. This CLV calculation helps you identify which customers are most valuable over time, not just based on a single large purchase.
-- Customer Lifetime Value calculation
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        COUNT(*) AS total_orders,
        SUM(order_amount) AS total_spent,
        AVG(order_amount) AS avg_order_value,
        MIN(order_date) AS first_order_date,
        MAX(order_date) AS last_order_date,
        (JULIANDAY(MAX(order_date)) - JULIANDAY(MIN(order_date)))/365.0 AS customer_age_years
    FROM customer_orders c
    JOIN payments p ON c.order_id = p.order_id
    WHERE p.payment_status = 'completed'
    GROUP BY c.customer_id
)
SELECT 
    customer_id,
    total_orders,
    total_spent,
    avg_order_value,
    customer_age_years,
    CASE 
        WHEN customer_age_years = 0 THEN total_spent
        ELSE total_spent / customer_age_years 
    END AS annual_value,
    -- Projected 3-year CLV assuming current behavior continues
    CASE 
        WHEN customer_age_years = 0 THEN total_spent * 3
        ELSE (total_spent / customer_age_years) * 3
    END AS projected_3yr_clv
FROM customer_metrics
ORDER BY projected_3yr_clv DESC;