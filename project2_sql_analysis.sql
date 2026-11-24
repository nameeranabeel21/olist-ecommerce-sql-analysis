-- =====================================================================
-- PROJECT 2: SQL Business Analysis (E-commerce)
-- Dataset: Brazilian E-Commerce by Olist (Kaggle) -- or any orders dataset.
-- Load the CSVs into SQLite/Postgres/MySQL first (see load_to_sqlite.py).
-- Syntax below is SQLite/Postgres-friendly. Notes mark MySQL differences.
--
-- Tables used (Olist names):
--   customers(customer_id, customer_unique_id, customer_city, customer_state)
--   orders(order_id, customer_id, order_status, order_purchase_timestamp, ...)
--   order_items(order_id, order_item_id, product_id, seller_id, price, freight_value)
--   products(product_id, product_category_name, ...)
--   order_payments(order_id, payment_type, payment_value, ...)
--   order_reviews(order_id, review_score, ...)
-- =====================================================================


-- Q1. How is revenue trending month over month?
-- Business use: spot seasonality and growth/decline.
WITH monthly AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS month,   -- Postgres: TO_CHAR(..., 'YYYY-MM')
        SUM(oi.price)                                  AS revenue,
        COUNT(DISTINCT o.order_id)                     AS orders
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
)
SELECT
    month,
    revenue,
    orders,
    LAG(revenue) OVER (ORDER BY month)                                       AS prev_month_revenue,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
          / LAG(revenue) OVER (ORDER BY month), 1)                           AS mom_growth_pct
FROM monthly
ORDER BY month;


-- Q2. Top 10 product categories by revenue, with share of total.
SELECT
    p.product_category_name                                    AS category,
    ROUND(SUM(oi.price), 2)                                    AS revenue,
    COUNT(*)                                                   AS items_sold,
    ROUND(100.0 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 2) AS pct_of_total
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
GROUP BY p.product_category_name
ORDER BY revenue DESC
LIMIT 10;


-- Q3. Who are the top 10 customers by lifetime spend?
-- (customer_unique_id identifies a real person; customer_id is per-order in Olist)
SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id)  AS orders,
    ROUND(SUM(oi.price), 2)     AS lifetime_value
FROM customers c
JOIN orders o       ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id   = o.order_id
GROUP BY c.customer_unique_id
ORDER BY lifetime_value DESC
LIMIT 10;


-- Q4. Repeat purchase rate: what % of customers bought more than once?
WITH per_customer AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS orders
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*)                                              AS total_customers,
    SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END)           AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_rate_pct
FROM per_customer;


-- Q5. Cohort retention: of customers who first bought in month X,
--     how many bought again in later months?
WITH first_order AS (
    SELECT c.customer_unique_id,
           MIN(strftime('%Y-%m', o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),
activity AS (
    SELECT DISTINCT c.customer_unique_id,
           strftime('%Y-%m', o.order_purchase_timestamp) AS active_month
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
)
SELECT
    f.cohort_month,
    a.active_month,
    COUNT(DISTINCT a.customer_unique_id) AS active_customers
FROM first_order f
JOIN activity a ON a.customer_unique_id = f.customer_unique_id
GROUP BY f.cohort_month, a.active_month
ORDER BY f.cohort_month, a.active_month;


-- Q6. Delivery performance: average days from purchase to delivery, by state.
-- Business use: find regions with logistics problems.
SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders,
    ROUND(AVG(julianday(o.order_delivered_customer_date)
            - julianday(o.order_purchase_timestamp)), 1) AS avg_delivery_days,   -- Postgres: DATE_PART('day', end - start)
    ROUND(100.0 * SUM(CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                           THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_late
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 100
ORDER BY avg_delivery_days DESC;


-- Q7. Does late delivery hurt review scores?
WITH delivery AS (
    SELECT o.order_id,
           CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
                THEN 'Late' ELSE 'On time' END AS delivery_status
    FROM orders o
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
)
SELECT
    d.delivery_status,
    COUNT(*)                         AS reviews,
    ROUND(AVG(r.review_score), 2)    AS avg_review_score
FROM delivery d
JOIN order_reviews r ON r.order_id = d.order_id
GROUP BY d.delivery_status;


-- Q8. Payment method mix and average order value.
SELECT
    payment_type,
    COUNT(DISTINCT order_id)                          AS orders,
    ROUND(AVG(payment_value), 2)                      AS avg_payment,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_payments
FROM order_payments
GROUP BY payment_type
ORDER BY orders DESC;


-- Q9. Pareto check: what % of revenue comes from the top 20% of sellers?
WITH seller_rev AS (
    SELECT seller_id, SUM(price) AS revenue
    FROM order_items
    GROUP BY seller_id
),
ranked AS (
    SELECT seller_id, revenue,
           NTILE(5) OVER (ORDER BY revenue DESC) AS quintile
    FROM seller_rev
)
SELECT
    quintile,
    COUNT(*)                                                  AS sellers,
    ROUND(SUM(revenue), 0)                                    AS revenue,
    ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS pct_of_revenue
FROM ranked
GROUP BY quintile
ORDER BY quintile;


-- Q10. RFM-style customer segments, computed purely in SQL.
WITH base AS (
    SELECT c.customer_unique_id,
           MAX(o.order_purchase_timestamp) AS last_order,
           COUNT(DISTINCT o.order_id)      AS frequency,
           SUM(oi.price)                   AS monetary
    FROM customers c
    JOIN orders o       ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id   = o.order_id
    GROUP BY c.customer_unique_id
),
scored AS (
    SELECT *,
           NTILE(4) OVER (ORDER BY last_order)  AS r_score,   -- 4 = most recent
           NTILE(4) OVER (ORDER BY monetary)    AS m_score
    FROM base
)
SELECT
    CASE
        WHEN frequency > 1 AND m_score = 4 THEN 'Champions'
        WHEN frequency > 1                 THEN 'Loyal'
        WHEN r_score = 4 AND m_score >= 3  THEN 'Promising new big spenders'
        WHEN r_score = 1                   THEN 'Lost / dormant'
        ELSE 'Regular one-time buyers'
    END AS segment,
    COUNT(*)                    AS customers,
    ROUND(AVG(monetary), 2)     AS avg_spend
FROM scored
GROUP BY segment
ORDER BY customers DESC;
