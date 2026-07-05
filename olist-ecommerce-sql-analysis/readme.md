# Olist E-Commerce Analysis — SQL & Power BI

## Project Overview

This project analyzes 100,000+ real Brazilian e-commerce transactions from Olist. It answers five critical business questions that directly impact revenue, customer retention, and operational strategy — starting with SQL across a normalized 9-table PostgreSQL database, then translating those findings into an interactive Power BI dashboard.

Every number in the SQL findings section below is reproducible directly from the queries provided. The dashboard visualizes those same findings for a non-technical stakeholder audience.

---

## Dataset

- **Source:** [Olist Brazilian E-Commerce Dataset — Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- **Size:** 99,441 orders | 96,096 unique customers | 3,095 sellers | 32,951 products
- **Period:** September 2016 — October 2018
- **Tables:** 9 (orders, customers, order_items, order_payments, order_reviews, products, sellers, geolocation, product_category_name_translation)

---

## Tools Used

- PostgreSQL 18
- pgAdmin 4
- SQL (CTEs, Window Functions, Multi-table JOINs, Aggregations)
- Power BI Desktop
- DAX (measures, calculated columns, calculated tables)

---

## Database Schema

```
customers ──── orders ──── order_items ──── products ──── product_category_name_translation
                  │
                  ├──── order_payments
                  │
                  └──── order_reviews

sellers ──── order_items

geolocation (zip code level geographic data)
```

---

## Business Questions & Findings

---

### 1. Which product categories generate the most revenue?

**Finding:** Health & beauty leads in total orders (9,670) with ₹1.25M revenue, but watches & gifts commands the highest average price (₹201 vs ₹130), indicating a premium buyer segment with fewer but higher-value transactions.

**Business Implication:** Marketing strategy should differentiate — volume campaigns for health & beauty, premium positioning for watches & gifts.

```sql
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
```

| Category | Total Orders | Total Revenue | Avg Price |
|---|---|---|---|
| health_beauty | 9,670 | ₹1,258,681 | ₹130 |
| watches_gifts | 5,991 | ₹1,205,005 | ₹201 |
| bed_bath_table | 11,115 | ₹1,036,988 | ₹93 |
| sports_leisure | 8,641 | ₹988,048 | ₹114 |
| computers_accessories | 7,827 | ₹911,954 | ₹116 |

---

### 2. Do late deliveries hurt review scores?

**Finding:** Late deliveries cause a 40% drop in average review score — from 4.29 (on-time) to 2.57 (late) — across 99,000+ reviewed orders. 7,701 orders were delivered late.

**Business Implication:** Every late delivery is a direct customer satisfaction risk. Logistics investment has a measurable ROI in review score improvement.

```sql
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
```

| Delivery Status | Total Reviews | Avg Review Score |
|---|---|---|
| On Time | 88,658 | 4.29 |
| Late | 7,701 | 2.57 |

---

### 3. What is the monthly revenue trend?

**Finding:** Revenue grew from ₹134 in September 2016 to ₹953,356 in March 2018 — a 700x increase over 23 months. A 36% revenue spike occurred in November 2017 (₹987,765 vs October's ₹648,247), consistent with Black Friday seasonal demand.

**Business Implication:** Inventory and logistics planning should account for Q4 seasonal spikes. November requires proactive capacity scaling.

```sql
SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp) as month,
    COUNT(DISTINCT o.order_id) as total_orders,
    ROUND(SUM(oi.price)::numeric, 2) as monthly_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_TRUNC('month', o.order_purchase_timestamp)
ORDER BY month ASC;
```

**Key Data Points:**

| Month | Total Orders | Monthly Revenue |
|---|---|---|
| Sep 2016 | 1 | ₹134 |
| Jan 2017 | 750 | ₹111,798 |
| Nov 2017 | 7,289 | ₹987,765 ← Peak |
| Mar 2018 | 7,003 | ₹953,356 |

---

### 4. Who are the top performing sellers and what makes them different?

**Finding:** The highest-volume seller (1,785 orders) scores only 3.80 in reviews, while a lower-volume seller (581 orders) achieves 4.34. High order volume does not guarantee customer satisfaction — quality and pricing strategy matter more.

**Business Implication:** Seller ranking systems should weight review scores alongside volume. Rewarding volume alone risks platform reputation.

```sql
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
```

---

### 5. What percentage of customers are repeat buyers?

**Finding:** 96.88% of customers (93,099) never place a second order. Only 0.26% (252 customers) qualify as loyal buyers with 3+ orders. This is the most critical business risk in the dataset.

**Business Implication:** Customer acquisition cost is being wasted at scale. A retention strategy targeting even 5% of one-time buyers could significantly impact lifetime revenue.

```sql
SELECT 
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
```

| Customer Segment | Total Customers | Percentage |
|---|---|---|
| One-time buyer | 93,099 | 96.88% |
| Returned once | 2,745 | 2.86% |
| Loyal customer (3+ orders) | 252 | 0.26% |

---

## Key Takeaways

| # | Finding | Impact |
|---|---|---|
| 1 | Watches/gifts buyers spend 55% more per order than health/beauty | Pricing strategy |
| 2 | Late delivery drops review score by 40% (4.29 → 2.57) | Logistics ROI |
| 3 | November 2017 revenue spike of 36% from seasonal demand | Inventory planning |
| 4 | Top seller by volume scores 3.80 vs 4.34 for lower-volume competitor | Seller quality metrics |
| 5 | 96.88% of customers never return — critical retention gap | Customer lifetime value |

---

## Power BI Dashboard

The five SQL findings above are visualized in an interactive Power BI dashboard, built on top of the same PostgreSQL database via a live connection.

**Dashboard views:**
- Revenue by product category (bar chart)
- Monthly revenue trend, highlighting the November 2017 seasonal spike (line chart)
- Delivery status vs. average review score (bar chart)
- Customer retention segmentation — one-time, returning, and loyal buyers (donut chart)
- Top 10 sellers by revenue vs. average review score (scatter plot)

**Built with:** Power BI Desktop, DAX measures for revenue, review score, late-delivery rate, and retention segmentation.

![Dashboard Screenshot](screenshots/dashboard_overview.png)

**Note on scope:** The retention and delivery-impact figures shown on the dashboard are cross-checked against the SQL query results above and match. The seller-level scatter plot is intended as an illustrative view of the volume-vs-satisfaction pattern rather than a rank-precise ranking; refer to Query 4 in `analysis_queries.sql` for exact seller-level figures.

---

## How to Reproduce

1. Download the dataset from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
2. Set up PostgreSQL and create a database called `olist_analysis`
3. Create all 9 tables using the schema definitions in `/sql/create_tables.sql`
4. Import each CSV into its corresponding table
5. Run queries from `/sql/analysis_queries.sql`
6. Open Power BI Desktop → Get Data → PostgreSQL Database → connect to `olist_analysis` → Import mode
7. Recreate the DAX measures listed in `/sql/dax_measures.txt`

---

## Author

**Deveshri Gurav**  
B.Tech Computer Science | Parul University  
[GitHub](https://github.com/Deveshri-Gurav-11) | [Portfolio](https://deveshri-gurav-11.github.io/portfolio)
