USE churn_intelligence_db;
SELECT COUNT(*) AS total_rows FROM ecommerce_churn;
USE churn_intelligence_db;

-- Global Business KPIs & Revenue at Risk

SELECT 
    COUNT(CustomerID) AS total_customers,
    SUM(CASE WHEN Churn = 0 THEN 1 ELSE 0 END) AS active_customers,
    SUM(CASE WHEN Churn = 1 THEN 1 ELSE 0 END) AS churned_customers,
    ROUND(AVG(Churn) * 100.0, 2) AS churn_rate_pct,
    ROUND((1.0 - AVG(Churn)) * 100.0, 2) AS retention_rate_pct,
    ROUND(SUM(CashbackAmount), 2) AS total_monetary_pool,
    ROUND(SUM(CASE WHEN Churn = 1 THEN CashbackAmount ELSE 0 END), 2) AS revenue_at_churn_risk
FROM ecommerce_churn;

USE churn_intelligence_db;

-- Churn by Product Category & Complaint Impact

SELECT 
    PreferedOrderCat AS product_category,
    Complain AS complaint_raised,
    COUNT(CustomerID) AS total_customers,
    SUM(Churn) AS churned_count,
    ROUND(AVG(Churn) * 100.0, 2) AS churn_rate_pct,
    ROUND(AVG(SatisfactionScore), 2) AS avg_satisfaction_score
FROM ecommerce_churn
GROUP BY PreferedOrderCat, Complain
ORDER BY product_category, complaint_raised;

-- Customer Lifecycle Cohort Retention (Using CTE)

USE churn_intelligence_db;

WITH CustomerLifecycle AS (
    SELECT 
        CustomerID,
        Churn,
        CashbackAmount,
        CASE 
            WHEN Tenure <= 3 THEN '01. 0-3 Months (New)'
            WHEN Tenure <= 6 THEN '02. 4-6 Months (Early)'
            WHEN Tenure <= 12 THEN '03. 7-12 Months (Mid)'
            WHEN Tenure <= 24 THEN '04. 13-24 Months (Established)'
            ELSE '05. 25+ Months (Mature)'
        END AS tenure_cohort
    FROM ecommerce_churn
)
SELECT 
    tenure_cohort,
    COUNT(CustomerID) AS cohort_size,
    SUM(CASE WHEN Churn = 1 THEN 1 ELSE 0 END) AS churned_count,
    ROUND(AVG(Churn) * 100.0, 2) AS churn_rate_pct,
    ROUND((1.0 - AVG(Churn)) * 100.0, 2) AS retention_rate_pct,
    ROUND(SUM(CashbackAmount), 2) AS cohort_monetary_pool
FROM CustomerLifecycle
GROUP BY tenure_cohort
ORDER BY tenure_cohort;

-- RFM Segmentation (Using Window Functions)

USE churn_intelligence_db;

WITH RFM_Base AS (
    SELECT 
        CustomerID,
        DaySinceLastOrder AS Recency,
        OrderCount AS Frequency,
        CashbackAmount AS Monetary,
        Churn
    FROM ecommerce_churn
),
RFM_Scored AS (
    SELECT 
        CustomerID,
        Recency,
        Frequency,
        Monetary,
        Churn,
        NTILE(5) OVER (ORDER BY Recency DESC) AS r_score,
        NTILE(5) OVER (ORDER BY Frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY Monetary ASC) AS m_score
    FROM RFM_Base
),
RFM_Segmentation AS (
    SELECT 
        CustomerID,
        Churn,
        Monetary,
        r_score,
        f_score,
        m_score,
        CASE 
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 3 AND f_score < 3 THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND (f_score >= 3 OR m_score >= 3) THEN 'At Risk'
            ELSE 'Lost / Hibernating'
        END AS rfm_segment
    FROM RFM_Scored
)
SELECT 
    rfm_segment,
    COUNT(CustomerID) AS total_customers,
    SUM(Churn) AS churned_customers,
    ROUND(AVG(Churn) * 100.0, 2) AS churn_rate_pct,
    ROUND(SUM(Monetary), 2) AS total_monetary_value,
    ROUND(AVG(Monetary), 2) AS avg_monetary_value
FROM RFM_Segmentation
GROUP BY rfm_segment
ORDER BY total_monetary_value DESC;

--

