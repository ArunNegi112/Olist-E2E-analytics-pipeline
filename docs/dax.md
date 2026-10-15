# DAX Measures

All measures are stored in the `_Measures` table of the Power BI report (`power_bi\AnalysisReport.pbix`). Most of them read from `analytics.fact_order_items`, where each row is one order item, so sums and distinct counts work at the right level of detail.

| Measure | Used for |
|---|---|
| [Total_Sales](#total_sales) | Revenue KPI, charts, state and category rankings |
| [Total_Orders](#total_orders) | Order count KPI, charts |
| [Average Order Value](#average-order-value) | Average order value KPI |
| [Average Order Value (including freight value)](#average-order-value-including-freight-value) | Alternative average order value |
| [Avg Freight Value](#avg-freight-value) | Average freight KPI |
| [Active Sellers](#active-sellers) | Active sellers KPI and trend |
| [Total_Sellers](#total_sellers) | Seller count |
| [Average of review_score star rating 2](#average-of-review_score-star-rating-2) | Star rating card |
| [Sales / Orders](#sales--orders) | Sales / Order Count toggle |
| [YoY Growth %](#yoy-growth-) | Year-over-year growth chart |

---

## Sales and Orders

### Total_Sales
Total revenue from item prices. Freight is not included.

```dax
Total_Sales = 
SUM('analytics fact_order_items'[price])
```

Each item is its own row, so buying the same product more than once in an order is counted correctly.

### Total_Orders
Number of distinct orders that have at least one item.

```dax
Total_Orders = 
DISTINCTCOUNT(
    'analytics fact_order_items'[order_id]
)
```

An order can have many item rows, so it counts **distinct** `order_id`s.

### Average Order Value
Average revenue per order, excluding freight.

```dax
Average Order Value = 
DIVIDE(
    SUM('analytics fact_order_items'[price]),
    DISTINCTCOUNT('analytics fact_order_items'[order_id])
)
```

### Average Order Value (including freight value)
Same as above, but with the shipping fee added to each order's value.

```dax
Average Order Value (including freight value) = 
DIVIDE(
    SUM('analytics fact_order_items'[price])
        + SUM('analytics fact_order_items'[freight_value]),
    DISTINCTCOUNT('analytics fact_order_items'[order_id])
)
```

### Avg Freight Value
Average shipping fee per item row.

```dax
Avg Freight Value = AVERAGE('analytics fact_order_items'[freight_value])
```

---

## Sellers

### Active Sellers
Number of distinct sellers with at least one item sold in the current filter (year, month, state, category).

```dax
Active Sellers = 
DISTINCTCOUNT(
    'analytics fact_order_items'[seller_id]
)
```

### Total_Sellers
Same calculation as `Active Sellers`.

```dax
Total_Sellers = 
DISTINCTCOUNT('analytics fact_order_items'[seller_id])
```

---

## Customer Satisfaction

### Average of review_score star rating 2
Turns the average review score into a row of stars (★ filled, ☆ empty) for the KPI card.

```dax
Average of review_score star rating 2 = 
VAR __MAX_NUMBER_OF_STARS = 5
VAR __MIN_RATED_VALUE = 1
VAR __MAX_RATED_VALUE = 5
VAR __BASE_VALUE = AVERAGE('analytics fact_reviews'[review_score])
VAR __NORMALIZED_BASE_VALUE =
	MIN(
		MAX(
			DIVIDE(
				__BASE_VALUE - __MIN_RATED_VALUE,
				__MAX_RATED_VALUE - __MIN_RATED_VALUE
			),
			0
		),
		1
	)
VAR __STAR_RATING = ROUND(__NORMALIZED_BASE_VALUE * __MAX_NUMBER_OF_STARS, 0)
RETURN
	IF(
		NOT ISBLANK(__BASE_VALUE),
		REPT(UNICHAR(9733), __STAR_RATING)
			& REPT(UNICHAR(9734), __MAX_NUMBER_OF_STARS - __STAR_RATING)
	)
```

How it works:
1. Take the average `review_score` (1 to 5).
2. Scale it to a 0 to 1 range, and keep it within those limits.
3. Multiply by 5 and round to a whole number of stars.
4. Repeat the filled star that many times, and fill the rest with empty stars.

The result is rounded to the nearest whole star, so an average of 4.2 shows as 4 stars.

---

## Sales / Orders Toggle and YoY Growth

### Sales / Orders
A small table (a field parameter) that lets the user switch charts between **Sales** and **Order Count** using the slicer on the left of the dashboard.

```dax
Sales / Orders = {
    ("Sales", NAMEOF('_Measures'[Total_Sales]), 0),
    ("Order Count", NAMEOF('_Measures'[Total_Orders]), 1)
}
```

Each row holds a label, the measure it points to, and an order number (0 or 1) that `YoY Growth %` reads.

### YoY Growth %
Year-over-year growth of whichever metric is selected in the toggle (Sales or Order Count).

```dax
YoY Growth % = 
VAR SelectedMetric =
    SELECTEDVALUE(
        'Sales / Orders'[Sales / Orders Order],
        0
    )

VAR CurrentValue =
    SWITCH(
        SelectedMetric,
        0, [Total_Sales],
        1, [Total_Orders]
    )

VAR PreviousYearValue =
    SWITCH(
        SelectedMetric,
        0,
            CALCULATE(
                [Total_Sales],
                SAMEPERIODLASTYEAR(
                    'analytics dim_date'[date_key]
                )
            ),
        1,
            CALCULATE(
                [Total_Orders],
                SAMEPERIODLASTYEAR(
                    'analytics dim_date'[date_key]
                )
            )
    )

RETURN
    DIVIDE(
        CurrentValue - PreviousYearValue,
        PreviousYearValue
    )
```

How it works:
1. Read which metric the user picked. If nothing is selected, it defaults to Sales (0).
2. Get the current value of that metric.
3. Get the value for the **same period one year earlier**, using `SAMEPERIODLASTYEAR` on the date table.
4. Return `(current − previous) / previous`.

Notes:
- The date table (`analytics.dim_date`) is a continuous calendar, which `SAMEPERIODLASTYEAR` needs.
- 2016 has no previous year, so it shows blank. 2016 has very few orders and 2018 data ends part-way through the year, so growth for those years is distorted by incomplete data.
