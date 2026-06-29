Olist E-Commerce SQL Analysis

Project Overview

This project analyzes 100,000+ real Brazilian e-commerce transactions from Olist using PostgreSQL. The goal was to answer five critical business questions that directly impact revenue, customer retention, and operational strategy — using only SQL across a normalized 9-table relational database.

All insights are derived from raw data with no pre-built dashboards or automated tools. Every finding is reproducible from the queries provided.


Dataset


Source: Olist Brazilian E-Commerce Dataset — Kaggle
Size: 99,441 orders | 96,096 unique customers | 3,095 sellers | 32,951 products
Period: September 2016 — October 2018
Tables: 9 (orders, customers, order_items, order_payments, order_reviews, products, sellers, geolocation, product_category_name_translation)



Tools Used


PostgreSQL 18
pgAdmin 4
SQL (CTEs, Window Functions, Multi-table JOINs, Aggregations)



Database Schema

customers ──── orders ──── order_items ──── products ──── product_category_name_translation
                  │
                  ├──── order_payments
                  │
                  └──── order_reviews

sellers ──── order_items

geolocation (zip code level geographic data)


Business Questions & Findings


1. Which product categories generate the most revenue?

Finding: Health & beauty leads in total orders (9,670) with ₹1.25M revenue, but watches & gifts commands the highest average price (₹201 vs ₹130), indicating a premium buyer segment with fewer but higher-value transactions.

Business Implication: Marketing strategy should differentiate — volume campaigns for health & beauty, premium positioning for watches & gifts.

sqlSELECT 
    t.product_category_name_english,
    COUNT(oi.order_id) as total_orders,
    ROUND(SUM(oi.price)::numeric, 2) as total_revenue,
    ROUND(AVG(oi.price)::numeric, 2) as avg_price
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN product_category_name_translation t 
    ON p.product_category_name = t.product_category_name
GROUP BY t.product_category_name_english
ORDER BY total_revenue DESC
LIMIT 10;

CategoryTotal OrdersTotal RevenueAvg Pricehealth_beauty9,670₹1,258,681₹130watches_gifts5,991₹1,205,005₹201bed_bath_table11,115₹1,036,988₹93sports_leisure8,641₹988,048₹114computers_accessories7,827₹911,954₹116


2. Do late deliveries hurt review scores?

Finding: Late deliveries cause a 40% drop in average review score — from 4.29 (on-time) to 2.57 (late) — across 99,000+ reviewed orders. 7,701 orders were delivered late.

Business Implication: Every late delivery is a direct customer satisfaction risk. Logistics investment has a measurable ROI in review score improvement.

sqlSELECT 
    CASE 
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date 
            THEN 'On Time'
        ELSE 'Late'
    END as delivery_status,
    COUNT(r.review_id) as total_reviews,
    ROUND(AVG(r.review_score)::numeric, 2) as avg_review_score
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status
ORDER BY avg_review_score DESC;

Delivery StatusTotal ReviewsAvg Review ScoreOn Time88,6584.29Late7,7012.57


3. What is the monthly revenue trend?

Finding: Revenue grew from ₹134 in September 2016 to ₹953,356 in March 2018 — a 700x increase over 23 months. A 36% revenue spike occurred in November 2017 (₹987,765 vs October's ₹648,247), consistent with Black Friday seasonal demand.

Business Implication: Inventory and logistics planning should account for Q4 seasonal spikes. November requires proactive capacity scaling.

sqlSELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp) as month,
    COUNT(DISTINCT o.order_id) as total_orders,
    ROUND(SUM(oi.price)::numeric, 2) as monthly_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month ASC;

Key Data Points:

MonthTotal OrdersMonthly RevenueSep 20161₹134Jan 2017750₹111,798Nov 20177,289₹987,765 ← PeakMar 20187,003₹953,356


4. Who are the top performing sellers and what makes them different?

Finding: The highest-volume seller (1,785 orders) scores only 3.80 in reviews, while a lower-volume seller (581 orders) achieves 4.34. High order volume does not guarantee customer satisfaction — quality and pricing strategy matter more.

Business Implication: Seller ranking systems should weight review scores alongside volume. Rewarding volume alone risks platform reputation.

sqlSELECT 
    oi.seller_id,
    COUNT(DISTINCT oi.order_id) as total_orders,
    ROUND(SUM(oi.price)::numeric, 2) as total_revenue,
    ROUND(AVG(r.review_score)::numeric, 2) as avg_review_score,
    ROUND(AVG(oi.price)::numeric, 2) as avg_order_value
FROM order_items oi
JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY oi.seller_id
HAVING COUNT(DISTINCT oi.order_id) > 50
ORDER BY total_revenue DESC
LIMIT 10;


5. What percentage of customers are repeat buyers?

Finding: 96.88% of customers (93,099) never place a second order. Only 0.26% (252 customers) qualify as loyal buyers with 3+ orders. This is the most critical business risk in the dataset.

Business Implication: Customer acquisition cost is being wasted at scale. A retention strategy targeting even 5% of one-time buyers could significantly impact lifetime revenue.

sqlSELECT 
    CASE 
        WHEN order_count = 1 THEN 'One-time buyer'
        WHEN order_count = 2 THEN 'Returned once'
        ELSE 'Loyal customer (3+ orders)'
    END as customer_segment,
    COUNT(*) as total_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM (
    SELECT 
        customer_unique_id,
        COUNT(order_id) as order_count
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY customer_unique_id
) customer_orders
GROUP BY customer_segment
ORDER BY total_customers DESC;

Customer SegmentTotal CustomersPercentageOne-time buyer93,09996.88%Returned once2,7452.86%Loyal customer (3+ orders)2520.26%


Key Takeaways

#FindingImpact1Watches/gifts buyers spend 55% more per order than health/beautyPricing strategy2Late delivery drops review score by 40% (4.29 → 2.57)Logistics ROI3November 2017 revenue spike of 36% from seasonal demandInventory planning4Top seller by volume scores 3.80 vs 4.34 for lower-volume competitorSeller quality metrics596.88% of customers never return — critical retention gapCustomer lifetime value


How to Reproduce


Download the dataset from Kaggle
Set up PostgreSQL and create a database called olist_analysis
Create all 9 tables using the schema definitions in /sql/create_tables.sql
Import each CSV into its corresponding table
Run queries from /sql/analysis_queries.sql
