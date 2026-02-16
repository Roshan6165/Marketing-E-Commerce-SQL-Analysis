
--Marketing E-COMMERCE ANALYTICS PORTFOLIO PROJECT
--------------------------------------------------
-- Description: 10 SQL queries covering Financials, User Behavior, and Marketing Performance.
-- Database: BigQuery (Standard SQL)
-- Author: [Roshan Kumar Gupta]

-- ==================================================
-- SECTION 1: FINANCIAL PERFORMANCE
-- ==================================================

-- KPI 1: Average Order Value (AOV) Trend
-- Goal: Monitor how the average spend per order changes month-over-month.
SELECT 
    FORMAT_DATE('%Y-%m', DATE(timestamp)) as Month,
    ROUND(AVG(total_amount), 2) as Average_Order_Value
FROM 
    `ecommerce.transactions`
GROUP BY 
    1
ORDER BY 
    1 DESC;

-- KPI 2: Refund Rate by Product Category
-- Goal: Identify categories with quality issues (high refund rates).
SELECT 
    category,
    ROUND(
        COALESCE(
            SAFE_DIVIDE(SUM(refund_amount), SUM(gross_revenue)), 
            0
        ) * 100, 2
    ) as Refund_Rate_Percent
FROM 
    `ecommerce.products`
GROUP BY 
    1
ORDER BY 
    2 DESC;

-- KPI 3: Discount Effectiveness by Loyalty Tier
-- Goal: See which customers receive the deepest discounts on average.
SELECT 
    c.loyalty_tier,
    ROUND(
        SUM(t.discount_amount) / SUM(t.gross_revenue) * 100, 
        2
    ) as Weighted_Avg_Discount_Percent
FROM 
    `ecommerce.transactions` t
JOIN 
    `ecommerce.customers` c 
    ON t.customer_id = c.customer_id
GROUP BY 
    1
ORDER BY 
    2 DESC;

-- ==================================================
-- SECTION 2: USER BEHAVIOR & RETENTION
-- ==================================================

-- KPI 4: Cart Abandonment Rate
-- Goal: Percentage of users who added items to cart but did not purchase.
-- Logic: Uses LIKE '%cart%' to capture generic event names, excludes 'remove'.
SELECT 
    (1 - ROUND(
        COALESCE(
            SAFE_DIVIDE(
                COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN session_id END),
                COUNT(DISTINCT CASE WHEN event_type LIKE '%cart%' AND event_type NOT LIKE '%remove%' THEN session_id END)
            ), 0
        ), 2
    )) * 100 AS Cart_Abandonment_Rate
FROM 
    `ecommerce.events`;

-- KPI 5: Customer Lifetime Value (CLV) by Channel
-- Goal: Identify acquisition channels that bring high-value customers.
SELECT 
    c.traffic_source,
    ROUND(
        COALESCE(
            SAFE_DIVIDE(SUM(t.gross_revenue), COUNT(DISTINCT t.customer_id)), 
            0
        ), 2
    ) AS Customer_Lifetime_Value
FROM 
    `ecommerce.transactions` t
LEFT JOIN 
    `ecommerce.customers` c
    ON t.customer_id = c.customer_id
GROUP BY 
    1
ORDER BY 
    2 DESC;

-- KPI 6: Repeat Purchase Rate by Loyalty Tier
-- Goal: Percentage of customers who have made more than 1 order.
-- Method: Uses a CTE to first calculate order counts per customer.
WITH Customer_Order_Counts AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT transaction_id) as total_orders
    FROM `ecommerce.transactions`
    GROUP BY 1
)
SELECT 
    c.loyalty_tier,
    ROUND(
        SAFE_DIVIDE(
            COUNT(CASE WHEN coc.total_orders > 1 THEN 1 END), -- Numerator: Repeat Buyers
            COUNT(*) -- Denominator: All Customers in Tier
        ) * 100, 2
    ) AS Repeat_Purchase_Rate
FROM 
    `ecommerce.customers` c
JOIN 
    Customer_Order_Counts coc 
    ON c.customer_id = coc.customer_id
GROUP BY 
    1
ORDER BY 
    2 DESC;

-- KPI 7: Average Days Since Last Purchase (Recency)
-- Goal: Measure customer "staleness" to identify churn risk.
WITH CustomerLastSeen AS (
    SELECT 
        customer_id,
        MAX(DATE(timestamp)) as last_purchase_date
    FROM `ecommerce.transactions`
    GROUP BY 1
)
SELECT 
    c.loyalty_tier,
    -- Calculates gap between Today and Last Purchase
    ROUND(AVG(DATE_DIFF(CURRENT_DATE(), cls.last_purchase_date, DAY)), 0) AS Avg_Days_Since_Purchase
FROM 
    `ecommerce.customers` c
JOIN 
    CustomerLastSeen cls 
    ON c.customer_id = cls.customer_id
GROUP BY 
    1
ORDER BY 
    2 DESC; -- Descending shows "coldest" customers first

-- ==================================================
-- SECTION 3: MARKETING & EXPERIMENTATION
-- ==================================================

-- KPI 8: Conversion Rate by Campaign Objective
-- Goal: Measure efficiency of different marketing goals (Acquisition vs Retention).
SELECT 
    c.objective,
    ROUND(
        COALESCE(
            SAFE_DIVIDE(
                COUNT(DISTINCT CASE WHEN e.event_type = 'purchase' THEN e.session_id END), -- Unique Purchasers
                COUNT(DISTINCT e.session_id) -- Unique Visitors
            ), 0
        ) * 100, 2
    ) AS Conversion_Rate
FROM 
    `ecommerce.campaigns` c
LEFT JOIN 
    `ecommerce.events` e
    ON c.campaign_id = e.campaign_id
GROUP BY 
    1
ORDER BY 
    2 DESC;

-- KPI 9: A/B Test Results (Experiment Uplift)
-- Goal: Compare Conversion Rate between 'Control' and 'Experiment' groups.
SELECT 
    e.experiment_group, 
    ROUND(
        COALESCE(
            SAFE_DIVIDE(
                COUNT(DISTINCT CASE WHEN LOWER(e.event_type) = 'purchase' THEN e.session_id END),
                COUNT(DISTINCT e.session_id)
            ), 0
        ) * 100, 2
    ) AS Conversion_Rate
FROM 
    `ecommerce.events` e
GROUP BY 
    1
ORDER BY 
    2 DESC;

-- KPI 10: Revenue Per Acquired Customer (Campaign Value)
-- Goal: Determine which campaigns bring in the highest spending customers.
-- Note: Used as a proxy for value since 'Cost' data was unavailable for CAC.
SELECT 
    c.objective,
    ROUND(
        COALESCE(
            SAFE_DIVIDE(
                SUM(t.gross_revenue), 
                COUNT(DISTINCT t.customer_id)
            ), 0
        ), 2
    ) AS Avg_Revenue_Per_Customer
FROM 
    `ecommerce.campaigns` c
JOIN 
    `ecommerce.transactions` t
    ON c.campaign_id = t.campaign_id
GROUP BY 
    1
ORDER BY 
    2 DESC;
