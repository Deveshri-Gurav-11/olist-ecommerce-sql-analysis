is queries · SQL
-- ============================================
-- Olist E-Commerce Business Analysis Queries
-- Database: olist_analysis
-- PostgreSQL 18
-- Author: Deveshri Gurav
-- ============================================
 
 
-- Query 1: Revenue by Product Category
-- Finding: Health & beauty leads in orders but watches & gifts
-- commands 55% higher average price (₹201 vs ₹130)
 
SELECT 
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
 
 
-- ============================================
 
 
-- Query 2: Delivery Impact on Review Scores
-- Finding: Late deliveries cause a 40% drop in review scores
-- (4.29 on-time vs 2.57 late) across 99,000+ orders
 
SELECT 
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
 
 
-- ============================================
 
 
-- Query 3: Monthly Revenue Trend
-- Finding: 700x revenue growth over 23 months with a 36% spike
-- in November 2017 linked to Black Friday seasonal demand
 
SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp) as month,
    COUNT(DISTINCT o.order_id) as total_orders,
    ROUND(SUM(oi.price)::numeric, 2) as monthly_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month ASC;
 
 
-- ============================================
 
 
-- Query 4: Seller Performance Analysis
-- Finding: High order volume does not guarantee customer satisfaction.
-- Top seller by volume (1,785 orders) scores 3.80 vs 4.34
-- for a lower-volume competitor (581 orders)
 
SELECT 
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
 
 
-- ============================================
 