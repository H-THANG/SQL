/* Question 0: Quantity sold out by Platform */

SELECT	 [platform]
		 ,SUM([quantity]) as sum_quantity
FROM	 [dbo].[dataset]
GROUP BY [platform];

/* Question 1: Sales performance(*) of each Platform in May 2024 (Revenue, Order, Item Sold, AOV (Average Order Value), ASP (Average Selling Price))
(*) The performance should exclude canceled, returned and failed order status. */

SELECT	 [platform]
		 ,SUM([quantity] * [unit_price]) AS 'Revenue'
		 ,COUNT(DISTINCT [order_number]) AS 'Order'
		 ,COUNT(DISTINCT [order_item_id]) AS 'Item Sold'
		 ,SUM([quantity] * [unit_price])/COUNT(DISTINCT [order_number]) AS 'Average Order Value'
		 ,SUM([quantity] * [unit_price])/SUM([quantity]) AS 'Average Selling Price'
FROM	 [dbo].[dataset]
WHERE	 DATEPART(YEAR, [order_created_date]) = 2024
	AND	 DATEPART(MONTH, [order_created_date]) = 5
	AND  [Order_status] NOT IN ('cancelled','returned','failed')
GROUP BY [platform]
;

/* Question 2: Top 5 revenue contributed Product SKU in May 2024 */

SELECT	 TOP 5 
		 [Product_SKU]
		 ,SUM([quantity] * [unit_price]) AS 'Revenue'
		 ,DENSE_RANK() OVER(ORDER BY SUM([quantity] * [unit_price]) DESC) AS RAK
FROM	 [dbo].[dataset]
WHERE	 DATEPART(YEAR, [order_created_date]) = 2024
	AND	 DATEPART(MONTH, [order_created_date]) = 5
	AND  [Order_status] NOT IN ('cancelled','returned','failed')
GROUP BY [Product_SKU]
;

/* Question 3: The first date that each Product SKU has been sold */

WITH	 DATE_PRO_SKU AS (
SELECT	 [Product_SKU]
		 ,[order_created_date]
		 ,DENSE_RANK() OVER(PARTITION BY [Product_SKU] ORDER BY [order_created_date]) AS RAK
FROM	 [dbo].[dataset]
GROUP BY [Product_SKU]
		 ,[order_created_date]
)

SELECT	 [Product_SKU]
		 ,[order_created_date]
FROM	 DATE_PRO_SKU
WHERE	 RAK = 1
;

/* Question 4: Seller Promotion Ratio (Seller Promotion/ Revenue) of each Product category. */

--SELECT	 [Product_SKU]
--		 ,FORMAT(SUM([seller_promo]) / SUM([quantity] * [unit_price]),'P') AS 'Seller_Promotion_Ratio'
--FROM	 [dbo].[dataset]
--WHERE    [Order_status] NOT IN ('cancelled','returned','failed')
--	AND  [quantity] * [unit_price] > 0
--GROUP BY [Product_SKU]
--ORDER BY 'Seller_Promotion_Ratio' DESC
--;


WITH	 Promotion_Ratio AS (
SELECT	 cate.[Category]
		 ,CAST(da.[seller_promo] as float) as seller_promo
		 ,CAST(da.[quantity] * da.[unit_price] as float) as revenue
FROM	 [dbo].[dataset] AS da
JOIN	 [dbo].[category] AS cate
	ON	 cate.[Product_SKU] = da.[Product_SKU]
WHERE    da.[Order_status] NOT IN ('cancelled','returned','failed')
	AND  da.[quantity] * da.[unit_price] > 0
)
SELECT	 [Category]
		 ,FORMAT(SUM(seller_promo) / SUM(revenue),'P') AS 'Seller_Promotion_Ratio'
FROM	 Promotion_Ratio
GROUP BY [Category]
ORDER BY 'Seller_Promotion_Ratio' DESC
;


/* Question 5: "Which Product SKU has the highest cancellation ratio in June 2024? And what is the main reason for cancellation of that product? ct?" */

WITH	 cancellation AS (
SELECT   [Product_SKU]
		 ,CAST(COUNT(*) AS FLOAT) AS COUNT_
		 ,CAST(SUM(COUNT(*)) OVER(ORDER BY [Product_SKU] ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS FLOAT) AS SUM_COUNT
FROM	 [dbo].[dataset]
WHERE    DATEPART(YEAR,[order_created_date]) = 2024
	AND  DATEPART(MONTH,[order_created_date]) = 6
	AND  [Order_status] = 'cancelled'
GROUP BY [Product_SKU]
)

		 ,highest_cancellation_ratio AS (
SELECT	 TOP 1 [Product_SKU]
		 ,FORMAT(COUNT_/SUM_COUNT,'P') AS 'cancellation_ratio'
FROM	 cancellation 
ORDER BY 'cancellation_ratio' DESC
)

		 ,reason_for_cancellation AS (
SELECT	 [Product_SKU], [cancelled_reason]
FROM	 [dbo].[dataset]
WHERE    DATEPART(YEAR,[order_created_date]) = 2024
	AND  DATEPART(MONTH,[order_created_date]) = 6
	AND  [Order_status] = 'cancelled'
	AND  [Product_SKU] = (SELECT [Product_SKU] FROM highest_cancellation_ratio)
)

SELECT	 TOP 1 [Product_SKU]
		 ,[cancelled_reason]
		 ,COUNT([cancelled_reason]) AS COUNT_2
FROM	 reason_for_cancellation
GROUP BY [Product_SKU], [cancelled_reason]
ORDER BY COUNT_2 DESC
;

/* Question 6: Percentage of late delivery orders of Shopee and Lazada( order has delivery lead time > = 3 days is considered as late order) */

WITH	 delivery_list AS (
SELECT	 [platform]
		 ,[Order_status]
		 ,[order_created_date]
		 ,[delivery_date]
		 ,DATEDIFF(DAY, [order_created_date], [delivery_date]) AS leadtime
FROM	 [dbo].[dataset]
WHERE	 DATEDIFF(DAY, [order_created_date], [delivery_date]) IS NOT NULL
	AND  [platform] IN ('shopee', 'lazada')
	AND  [Order_status] IN ('delivered','shipped')
)
		 ,leadtime_list AS (
SELECT	 [platform]
		 ,CAST(COUNT(*) AS FLOAT) AS COUNT_
FROM	 delivery_list
WHERE	 leadtime >=3
GROUP BY [platform]
)
		 ,total_list AS (
SELECT	 [platform]
		 ,CAST(COUNT(*) AS FLOAT) AS TOTAL_
FROM	 delivery_list
GROUP BY [platform]
)
SELECT	 ll.[platform] 
		 ,FORMAT(COUNT_/TOTAL_,'P') AS 'Percentage_of_late_delivery_orders'
FROM	 leadtime_list AS ll
JOIN	 total_list AS tl
	ON	 ll.[platform] = tl.[platform]
ORDER BY 'Percentage_of_late_delivery_orders' DESC
;


/*Track the Sales Performance on weekly basis per platform*/

ALTER TABLE [dbo].[dataset]
ALTER COLUMN [quantity] bigint;

SELECT	 [platform]
		 ,SUM([quantity] * [unit_price]) AS 'Revenue'
		 ,COUNT(DISTINCT [order_number]) AS 'Order'
		 ,COUNT(DISTINCT [order_item_id]) AS 'Item Sold'
		 ,SUM([quantity] * [unit_price]) / COUNT(DISTINCT [order_number]) AS 'Average Order Value'
		 ,SUM([quantity] * [unit_price]) / SUM([quantity]) AS 'Average Selling Price'
		 ,SUM([quantity]) AS 'Quantity'
		 ,DATEPART(WEEK, [order_created_date]) AS 'Week num'
FROM	 [dbo].[dataset]
WHERE	 [Order_status] NOT IN ('cancelled','returned','failed')
GROUP BY [platform]
		 ,DATEPART(WEEK, [order_created_date])
ORDER BY 'Week num' 
;
with	 CTE1 AS (
SELECT	 [platform]
		 ,SUM([quantity] * [unit_price]) AS 'Revenue'
		 ,COUNT(DISTINCT [order_number]) AS 'Order'
		 ,COUNT(DISTINCT [order_item_id]) AS 'Item Sold'
		 ,SUM([quantity] * [unit_price]) / COUNT(DISTINCT [order_number]) AS 'Average Order Value'
		 ,SUM([quantity] * [unit_price]) / SUM([quantity]) AS 'Average Selling Price'
		 ,SUM([quantity]) AS 'Quantity'
		 ,DATEPART(WEEK, [order_created_date]) AS 'Week num'
FROM	 [dbo].[dataset]
WHERE	 [Order_status] NOT IN ('cancelled','returned','failed')
GROUP BY [platform]
		 ,DATEPART(WEEK, [order_created_date])
)
SELECT	 SUM(revenue) AS 'Revenue'
		 ,SUM([Order]) AS 'Orders'
		 ,SUM([Item Sold]) AS 'Item Sold'
		 ,SUM(revenue) / SUM([Order]) AS 'Average Order Value'
		 ,SUM(revenue) / SUM(Quantity) AS 'Average Selling Price'
FROM	 CTE1
;

/* Track the Seller Promotion amount and Seller Promotion % on weekly basis by platform */

SELECT	 [platform]
		 ,DATEPART(WEEK, [order_created_date]) AS 'Week num'
		 ,SUM([seller_promo]) AS 'Seller Promotion amount'
		 ,FORMAT(SUM([seller_promo]) / SUM([quantity] * [unit_price]),'P') AS 'Seller_Promotion_Ratio'
FROM	 [dbo].[dataset]
WHERE    [Order_status] NOT IN ('cancelled','returned','failed')
	AND  [quantity] * [unit_price] > 0
GROUP BY [platform]
		 ,DATEPART(WEEK, [order_created_date])
ORDER BY 'Week num'
;

/* Track the cancel Ratio and the main reason on weekly basis */

WITH	 cancellation AS (
SELECT   [platform]
		 ,DATEPART(WEEK, [order_created_date]) AS 'Week num'
		 ,CAST(COUNT(*) AS FLOAT) AS COUNT_
		 ,CAST(SUM(COUNT(DATEPART(WEEK, [order_created_date]))) OVER( PARTITION BY DATEPART(WEEK, [order_created_date]) 
																	  ORDER BY DATEPART(WEEK, [order_created_date])
																	  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS FLOAT) AS SUM_COUNT
FROM	 [dbo].[dataset]
WHERE    [Order_status] = 'cancelled'
GROUP BY [platform]
		 ,DATEPART(WEEK, [order_created_date]) 
)

		 ,highest_cancellation_ratio AS (
SELECT	 [platform]
		 ,[Week num]
		 ,FORMAT(COUNT_/SUM_COUNT,'P') AS 'cancellation_ratio'
FROM	 cancellation 
--ORDER BY [Week num]
--		 ,'cancellation_ratio' DESC
)

		 ,reason_for_cancellation AS (
SELECT	 [platform]
		 ,[cancelled_reason]
		 ,DATEPART(WEEK, [order_created_date]) AS 'Week num'
FROM	 [dbo].[dataset]
WHERE    [Order_status] = 'cancelled'
	AND  [platform] in (SELECT [platform] FROM highest_cancellation_ratio)
)

SELECT	 [platform]
		 ,[Week num]
		 ,[cancelled_reason]
		 ,COUNT([cancelled_reason]) AS COUNT_2
FROM	 reason_for_cancellation
GROUP BY [platform]
		 ,[Week num]
		 ,[cancelled_reason]	 
ORDER BY [Week num]
		 ,[platform]
		 ,COUNT_2 DESC
;

WITH	 cancellation AS (
SELECT   [platform]
		 ,DATEPART(WEEK, [order_created_date]) AS 'Week num'
		 ,CAST(COUNT(*) AS FLOAT) AS COUNT_
		 ,CAST(SUM(COUNT(DATEPART(WEEK, [order_created_date]))) OVER( PARTITION BY DATEPART(WEEK, [order_created_date]) 
																	  ORDER BY DATEPART(WEEK, [order_created_date])
																	  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS FLOAT) AS SUM_COUNT
FROM	 [dbo].[dataset]
WHERE    [Order_status] = 'cancelled'
GROUP BY [platform]
		 ,DATEPART(WEEK, [order_created_date]) 
)
SELECT	 [platform]
		 ,[Week num]
		 ,FORMAT(COUNT_/SUM_COUNT,'P') AS 'cancellation_ratio'
FROM	 cancellation 
ORDER BY [Week num] 
		 ,'cancellation_ratio' DESC
;