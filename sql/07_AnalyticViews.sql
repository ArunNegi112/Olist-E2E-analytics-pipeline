-- Contains first and last 'purchase dates' for each year

CREATE VIEW analytics.date_limits AS
    SELECT 
        min(purchase_date) AS first_date,
        max(purchase_date) AS last_date
    FROM 
        analytics.dim_order
    GROUP BY 
        EXTRACT(YEAR FROM purchase_date)
    ORDER BY 
        EXTRACT(YEAR FROM purchase_date)
;

SELECT * FROM analytics.date_limits;
