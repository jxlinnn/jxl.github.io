DROP TABLE IF EXISTS sql_project.walmart_sales;

CREATE TABLE IF NOT EXISTS sql_project.walmart_sales
(
    store integer,
    sales_date character varying,
    weekly_sales real,
    holiday_flag integer,
    temperature real,
    fuel_price real,
    cpi real,
    unemployment real
)


-- Average weekly sales for a local store
SELECT store, AVG(weekly_sales) 
FROM walmart.sales
GROUP BY store
ORDER BY store;


-- Average weekly sales during holidays vs non-holiday periods
WITH t1 as (
	SELECT
		store,
		ROUND(AVG(weekly_sales)::numeric, 2) as other_avg_sales
	FROM walmart.sales
	WHERE holiday_flag = 0
	GROUP BY store
), t2 AS (
	SELECT 
		store,
		ROUND(AVG(weekly_sales)::numeric, 2) as holiday_avg_sales
	FROM walmart.sales
	WHERE holiday_flag = 1
	GROUP BY store
)
SELECT
	t1.store,
	t1.other_avg_sales,
	t2.holiday_avg_sales,
	(t1.other_avg_sales-t2.holiday_avg_sales) AS difference
FROM t1 
LEFT JOIN t2
  ON t1.store = t2.store
ORDER BY t1.store;


-- Compare total annual sales per year and compute percentage change
SELECT
	sales_year,
	ROUND((total_sales/1000000000)::numeric, 2) AS sales_in_billions,
	CASE 
		WHEN sales_year > 2010 THEN
			100*(total_sales - LAG(total_sales) OVER (ORDER BY sales_year))/(LAG(total_sales) OVER(ORDER BY sales_year))
		ELSE 0
	END AS percentage_change
FROM
(
	SELECT
		DATE_PART('year', TO_DATE(sales_date, 'DD-MM-YYYY')) AS sales_year,
		SUM(weekly_sales) as total_sales
	FROM walmart.sales
	GROUP BY sales_year
) AS t1
GROUP BY sales_year, total_sales


-- Highest monthly sales per year
WITH t1 as (
	SELECT
		DATE_PART('year', TO_DATE(sales_date, 'DD-MM-YYYY')) AS sales_year,
		DATE_PART('month', TO_DATE(sales_date, 'DD-MM-YYYY')) AS sales_month,
		SUM(weekly_sales) AS monthly_sales
	FROM walmart.sales
	GROUP BY sales_year, sales_month
)
SELECT
	sales_year,
	sales_month,
	ROUND((monthly_sales/1000000)::numeric, 2) AS monthly_sales_in_millions
FROM
(SELECT
 	*,
	ROW_NUMBER() OVER (PARTITION BY sales_year ORDER BY monthly_sales DESC) AS row_num
FROM t1) AS t2
WHERE row_num = 1
ORDER BY sales_year, sales_month


-- Measure effect of cpi and unemployment on monthly sales 
WITH t1 AS (
	SELECT
		DATE_PART('year', TO_DATE(sales_date, 'DD-MM-YYYY')) AS sales_year,
		DATE_PART('month', TO_DATE(sales_date, 'DD-MM-YYYY')) AS sales_month,
		weekly_sales,
		unemployment,
		cpi
	FROM walmart.sales
),
t2 AS (
	SELECT 
		t1.sales_year,
		t1.sales_month,
		SUM(t1.weekly_sales) AS monthly_sales,
		AVG(t1.unemployment) AS avg_unemployment,
		AVG(t1.cpi) AS avg_cpi
	FROM t1
	GROUP BY 1,2
)
SELECT 
	t1.sales_year,
	t1.sales_month,
	MAX(t2.monthly_sales),
	MAX(t1.unemployment) - t2.avg_unemployment AS unemployment_diff,
	MAX(t1.cpi) - t2.avg_cpi AS cpi_diff

FROM t1
	JOIN t2
		ON t1.sales_year = t2.sales_year
		AND t1.sales_month = t2.sales_month
GROUP BY t1.sales_year, t1.sales_month, t2.avg_unemployment, t2.avg_cpi
ORDER BY 1,2
