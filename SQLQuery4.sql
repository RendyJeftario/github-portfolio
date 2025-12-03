USE [Cohort Subs]; -- Pakai kurung siku karena ada spasi
GO

---Cleaning Data

---Total Records = 541909
---135080 Records have no customerID
---406829 Records have customerID
IF OBJECT_ID('tempdb..#online_retail_main') IS NOT NULL DROP TABLE #online_retail_main;
IF OBJECT_ID('tempdb..#cohort') IS NOT NULL DROP TABLE #cohort;
IF OBJECT_ID('tempdb..#cohort_retention') IS NOT NULL DROP TABLE #cohort_retention;
IF OBJECT_ID('tempdb..#cohort_pivot') IS NOT NULL DROP TABLE #cohort_pivot;


;with online_retail as
(
	SELECT [InvoiceNo]
		  ,[StockCode]
		  ,[Description]
		  ,[Quantity]
		  ,[InvoiceDate]
		  ,[UnitPrice]
		  ,[CustomerID]
		  ,[Country]
	  -- Pastikan nama tabel ini sesuai dengan yang ada di Object Explorer Anda
	  FROM [dbo].[Online Retail New]
	  Where CustomerID != 0
)
, quantity_unit_price as 
(
	---397882 records with quantity and Unit price
	select *
	from online_retail
	where Quantity > 0 and UnitPrice > 0
)
, dup_check as
(
	---duplicate check
	select * , ROW_NUMBER() over (partition by InvoiceNo, StockCode, Quantity order by InvoiceDate)dup_flag
	from quantity_unit_price

)
---397667 clean data
--5215 duplicate records
select *
into #online_retail_main
from dup_check
where dup_flag = 1

----Clean Data
----BEGIN COHORT ANALYSIS
select * from #online_retail_main

--Unique Identifier (CustomerID)
--Initial Start Date (First Invoice Date)
--Revenue Data

select
	CustomerID,
	min(InvoiceDate) first_purchase_date,
	DATEFROMPARTS(year(min(InvoiceDate)), month(min(InvoiceDate)), 1) Cohort_Date
into #cohort
from #online_retail_main
group by CustomerID

select *
from #cohort

---Create Cohort Index
select
	mmm.*,
	cohort_index = year_diff * 12 + month_diff + 1
into #cohort_retention
from
	(
		select
			mm.*,
			year_diff = invoice_year - cohort_year,
			month_diff = invoice_month - cohort_month
		from
			(
				select
					m.*,
					c.Cohort_Date,
					year(m.InvoiceDate) invoice_year,
					month(m.InvoiceDate) invoice_month,
					year(c.Cohort_Date) cohort_year,
					month(c.Cohort_Date) cohort_month
				from #online_retail_main m
				left join #cohort c
					on m.CustomerID = c.CustomerID
			)mm
	)mmm
--where CustomerID = 14733


---Pivot Data to see the cohort table
select 	*
into #cohort_pivot
from(
	select distinct 
		CustomerID,
		Cohort_Date,
		cohort_index
	from #cohort_retention
)tbl
pivot(
	Count(CustomerID)
	for Cohort_Index In 
		(
		[1], 
        [2], 
        [3], 
        [4], 
        [5], 
        [6], 
        [7],
		[8], 
        [9], 
        [10], 
        [11], 
        [12],
		[13])

)as pivot_table

select *
from #cohort_pivot
order by Cohort_Date

--- CALCULATION (PERCENTAGE)
--- Saya tambahkan NULLIF agar tidak error 'Divide by Zero'
select Cohort_Date ,
	(1.0 * [1]/NULLIF([1],0) * 100) as [1], 
    1.0 * [2]/NULLIF([1],0) * 100 as [2], 
    1.0 * [3]/NULLIF([1],0) * 100 as [3],  
    1.0 * [4]/NULLIF([1],0) * 100 as [4],  
    1.0 * [5]/NULLIF([1],0) * 100 as [5], 
    1.0 * [6]/NULLIF([1],0) * 100 as [6], 
    1.0 * [7]/NULLIF([1],0) * 100 as [7], 
	1.0 * [8]/NULLIF([1],0) * 100 as [8], 
    1.0 * [9]/NULLIF([1],0) * 100 as [9], 
    1.0 * [10]/NULLIF([1],0) * 100 as [10],    
    1.0 * [11]/NULLIF([1],0) * 100 as [11],  
    1.0 * [12]/NULLIF([1],0) * 100 as [12],  
	1.0 * [13]/NULLIF([1],0) * 100 as [13]
from #cohort_pivot
order by Cohort_Date





---DYNAMIC SQL TO CREATE PIVOT TABLE

DECLARE 
    @columns NVARCHAR(MAX) = '',
	@sql     NVARCHAR(MAX) = '';

SELECT 
    @columns += QUOTENAME(cohort_index) + ','
FROM 
    (select distinct cohort_index from #cohort_retention) m
ORDER BY 
    cohort_index;

SET @columns = LEFT(@columns, LEN(@columns) - 1);

PRINT @columns;


-- construct dynamic SQL
SET @sql ='

---# Return number of unique elements in the object
SELECT * FROM    
(
	  select distinct
		Cohort_Date,
		cohort_index,
		CustomerID 
	  from #cohort_retention
) t 
PIVOT(
    COUNT(CustomerID) 
    FOR cohort_index IN ('+ @columns +')
) AS pivot_table
order by Cohort_Date


';

-- execute the dynamic SQL
EXECUTE sp_executesql @sql;

select*from #cohort_retention