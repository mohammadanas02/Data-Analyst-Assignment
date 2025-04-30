-- 1. This provides your fundamental payment success rate. For example, if you see that 3.5% of payments are failing, you can benchmark this against industry standards (typically 2-5% for e-commerce).

-- Basic payment status distribution
SELECT 
    payment_status,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM payments), 2) AS percentage,
    SUM(payment_amount) AS total_amount
FROM payments
GROUP BY payment_status
ORDER BY count DESC;

-- 2. This analysis might reveal that certain payment methods have significantly higher failure rates. For example, if digital wallets show a 2% failure rate while credit cards show 7%, this indicates a potential integration issue with your credit card processor.

-- Payment success/failure by payment method
SELECT 
    payment_method,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN payment_status = 'completed' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN payment_status = 'failed' THEN 1 ELSE 0 END) AS failed,
    ROUND(SUM(CASE WHEN payment_status = 'failed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS failure_rate,
    AVG(CASE WHEN payment_status = 'completed' THEN payment_amount END) AS avg_successful_amount
FROM payments
GROUP BY payment_method
ORDER BY failure_rate DESC;

-- 3. This might reveal seasonal patterns or point to specific incidents. For example, a spike in failures during December could indicate capacity issues during holiday shopping peaks.

-- Payment failure trends over time
SELECT 
    strftime('%Y-%m', payment_date) AS month,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN payment_status = 'completed' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN payment_status = 'failed' THEN 1 ELSE 0 END) AS failed,
    ROUND(SUM(CASE WHEN payment_status = 'failed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS failure_rate
FROM payments
GROUP BY month
ORDER BY month;

-- 4. This sql query might show that 65% of orders succeed on the first attempt, while 80% eventually succeed after retries, indicating the value of your retry strategy.

-- Payment retry analysis
WITH payment_attempts AS (
    SELECT 
        order_id,
        COUNT(*) AS attempt_count,
        SUM(CASE WHEN payment_status = 'completed' THEN 1 ELSE 0 END) AS successful_attempts,
        MIN(CASE WHEN payment_status = 'completed' THEN payment_date ELSE NULL END) AS success_date,
        MIN(payment_date) AS first_attempt_date
    FROM payments
    GROUP BY order_id
)
SELECT 
    attempt_count,
    COUNT(*) AS orders,
    SUM(CASE WHEN successful_attempts > 0 THEN 1 ELSE 0 END) AS eventually_successful,
    ROUND(SUM(CASE WHEN successful_attempts > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS recovery_rate,
    AVG(JULIANDAY(success_date) - JULIANDAY(first_attempt_date)) AS avg_days_to_success
FROM payment_attempts
GROUP BY attempt_count
ORDER BY attempt_count;


-- 5. This might reveal that you have $25,000 in pending orders that haven't been paid for, with the average unpaid order being 5 days old.
-- Orders without successful payments
SELECT 
    c.order_status,
    COUNT(DISTINCT c.order_id) AS unpaid_orders,
    SUM(c.order_amount) AS total_unpaid_amount,
    AVG(c.order_amount) AS avg_unpaid_order_value,
    AVG(JULIANDAY('now') - JULIANDAY(c.order_date)) AS avg_days_outstanding
FROM customer_orders c
LEFT JOIN payments p ON c.order_id = p.order_id AND p.payment_status = 'completed'
WHERE p.payment_id IS NULL
GROUP BY c.order_status
ORDER BY unpaid_orders DESC;

-- 6. This might reveal that 5% of your repeat customers experience persistent payment issues, suggesting potential fraud flags or card problems.

-- Payment reliability for repeat customers
WITH customer_payments AS (
    SELECT 
        c.customer_id,
        COUNT(DISTINCT c.order_id) AS total_orders,
        SUM(CASE WHEN p.payment_status = 'completed' THEN 1 ELSE 0 END) AS successful_payments,
        SUM(CASE WHEN p.payment_status = 'failed' THEN 1 ELSE 0 END) AS failed_payments
    FROM customer_orders c
    LEFT JOIN payments p ON c.order_id = p.order_id
    GROUP BY c.customer_id
    HAVING total_orders > 1
)
SELECT 
    CASE 
        WHEN failed_payments = 0 THEN 'No failures'
        WHEN failed_payments * 1.0 / total_orders < 0.1 THEN 'Occasional failures (<10%)'
        WHEN failed_payments * 1.0 / total_orders < 0.3 THEN 'Frequent failures (10-30%)'
        ELSE 'High failure rate (>30%)'
    END AS failure_category,
    COUNT(*) AS customer_count,
    AVG(total_orders) AS avg_orders_per_customer,
    SUM(total_orders) AS total_orders,
    SUM(failed_payments) AS total_failures,
    ROUND(SUM(failed_payments) * 100.0 / SUM(total_orders), 2) AS overall_failure_rate
FROM customer_payments
GROUP BY failure_category
ORDER BY overall_failure_rate;

