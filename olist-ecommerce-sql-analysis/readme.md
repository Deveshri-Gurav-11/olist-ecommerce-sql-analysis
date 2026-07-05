-- ============================================
-- Olist Dashboard — DAX Measures & Calculated Tables
-- Power BI Desktop
-- ============================================


-- Measure: Total Revenue
Total Revenue = 
SUMX(
    'public order_items',
    'public order_items'[price]
)


-- Measure: Average Review Score
Avg Review Score = 
AVERAGE('public order_reviews'[review_score])


-- Measure: Late Delivery Rate %
Late Delivery Rate % = 
VAR LateOrders =
    CALCULATE(
        COUNTROWS('public orders'),
        'public orders'[order_delivered_customer_date] > 
        'public orders'[order_estimated_delivery_date]
    )
VAR TotalOrders =
    CALCULATE(
        COUNTROWS('public orders'),
        NOT ISBLANK('public orders'[order_delivered_customer_date])
    )
RETURN
    DIVIDE(LateOrders, TotalOrders) * 100


-- Measure: One Time Customer Rate %
One Time Customer Rate % = 
VAR CustomerOrderCount =
    ADDCOLUMNS(
        VALUES('public customers'[customer_unique_id]),
        "OrderCount",
        CALCULATE(COUNTROWS('public orders'))
    )
VAR OneTimers =
    COUNTX(
        FILTER(CustomerOrderCount, [OrderCount] = 1),
        [customer_unique_id]
    )
VAR TotalCustomers =
    COUNTROWS(CustomerOrderCount)
RETURN
    DIVIDE(OneTimers, TotalCustomers) * 100


-- Measure: Total Orders
Total Orders = 
DISTINCTCOUNT('public orders'[order_id])


-- Calculated Column (on public orders): Delivery Status
Delivery Status = 
IF(
    'public orders'[order_delivered_customer_date] <= 
    'public orders'[order_estimated_delivery_date],
    "On Time",
    "Late"
)


-- Calculated Table: Seller Summary
-- Pre-aggregates order_items to seller grain, avoiding
-- context-transition errors when ranking sellers.
Seller Summary = 
ADDCOLUMNS(
    SUMMARIZE('public order_items', 'public order_items'[seller_id]),
    "Total Revenue", CALCULATE(SUM('public order_items'[price])),
    "Avg Review Score", CALCULATE(AVERAGE('public order_reviews'[review_score]))
)


-- Calculated Column (on Seller Summary): Seller Rank
Seller Rank = 
"Seller #" & RANKX('Seller Summary', [Total Revenue], , DESC, Dense)


-- Calculated Table: Customer Segments
-- Static reference table matching Query 5 (SQL) results.
Customer Segments = 
DATATABLE(
    "Segment", STRING,
    "Customers", INTEGER,
    "Percentage", DECIMAL,
    {
        {"One-time buyer", 93099, 96.88},
        {"Returned once", 2745, 2.86},
        {"Loyal (3+ orders)", 252, 0.26}
    }
)
