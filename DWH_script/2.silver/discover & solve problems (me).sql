/* 
===============================================================================
DATA PROFILING & DATA QUALITY ASSESSMENT CHECKLIST
Purpose:
    Before transforming data from the Bronze layer to the Silver layer,
    perform a systematic data profiling process to identify data quality
    issues and define the required cleansing and transformation rules.

===============================================================================
STEP 1: Understand the Data
-------------------------------------------------------------------------------
- Review the table schema and column data types.
- Identify the business key / primary key.
- Understand the business meaning of each column.
- Define business rules and expected values.

Examples:
- Customer ID must be unique.
- Gender should be Male or Female.
- Birth dates cannot be in the future.
- Sales = Quantity × Price.

===============================================================================
STEP 2: Explore the Dataset
-------------------------------------------------------------------------------
- Count the total number of records.
- Preview sample records.
- Review column data types.

Checks:
- Total row count
- SELECT TOP (100) *
- Data type validation

===============================================================================
STEP 3: Check Data Completeness
-------------------------------------------------------------------------------
Goal:
    Identify missing or incomplete information.

Checks:
- NULL values
- Empty strings
- Mandatory fields

Typical SQL:
- COUNT(*) WHERE column IS NULL
- COUNT(*) WHERE column = ''

===============================================================================
STEP 4: Check Data Uniqueness
-------------------------------------------------------------------------------
Goal:
    Detect duplicate business keys.

Checks:
- Duplicate customer IDs
- Duplicate product IDs
- Duplicate transaction IDs

Typical SQL:
- GROUP BY key
- HAVING COUNT(*) > 1

===============================================================================
STEP 5: Check Categorical Values
-------------------------------------------------------------------------------
Goal:
    Identify inconsistent or unexpected values.

Checks:
- DISTINCT values
- Mixed casing
- Abbreviations
- Misspellings
- Unknown values

Examples:
M, Male, male
F, Female
S, Single
M, Married

===============================================================================
STEP 6: Check Text Quality
-------------------------------------------------------------------------------
Goal:
    Detect formatting issues.

Checks:
- Leading spaces
- Trailing spaces
- Empty strings
- Unexpected string lengths
- Invalid characters

Typical functions:
- TRIM()
- LEN()
- REPLACE()

===============================================================================
STEP 7: Validate Numeric Data
-------------------------------------------------------------------------------
Goal:
    Detect invalid numeric values.

Checks:
- Negative values
- Zero values (when not allowed)
- Missing values
- Unrealistic values

Examples:
Price <= 0
Quantity < 0
Cost IS NULL

===============================================================================
STEP 8: Validate Date Columns
-------------------------------------------------------------------------------
Goal:
    Ensure date values are valid and logically consistent.

Checks:
- Invalid dates
- Future dates
- Missing dates
- Date sequence validation

Examples:
Ship Date >= Order Date
Due Date >= Order Date
Birth Date <= Current Date

===============================================================================
STEP 9: Check Referential Integrity
-------------------------------------------------------------------------------
Goal:
    Verify relationships between tables.

Checks:
- Orphan records
- Missing parent records
- Invalid foreign keys

Examples:
Sales Customer ID exists in Customer table
Sales Product ID exists in Product table

===============================================================================
STEP 10: Validate Business Rules
-------------------------------------------------------------------------------
Goal:
    Ensure data satisfies business logic.

Examples:
- Sales = Quantity × Price
- Loan Amount = Monthly Payment × Number of Months
- Product End Date > Product Start Date

Business rules are often the most important source of data quality issues.

===============================================================================
STEP 11: Detect Outliers
-------------------------------------------------------------------------------
Goal:
    Identify unusual or unrealistic values.

Checks:
- Minimum values
- Maximum values
- Average values
- Top/Bottom records

Examples:
Highest sales
Oldest customer
Largest transaction

===============================================================================
STEP 12: Document All Findings
-------------------------------------------------------------------------------
For every issue discovered, document:

1. Issue Description
2. Discovery SQL Query
3. Root Cause
4. Transformation Rule
5. Expected Result

Documentation Template:

Issue:
    Duplicate Customer IDs

Discovery:
    SELECT cst_id, COUNT(*)
    FROM bronze.crm_cust_info
    GROUP BY cst_id
    HAVING COUNT(*) > 1;

Transformation:
    Keep the latest record using ROW_NUMBER()
    ordered by Create Date.

===============================================================================
STEP 13: Implement Silver Transformations
-------------------------------------------------------------------------------
Only after completing all profiling steps should transformation logic
be implemented.

Typical transformations include:

- Remove duplicates
- Filter invalid records
- Handle NULL values
- Standardize categorical values
- Trim text
- Correct data types
- Validate business rules
- Derive calculated columns
- Generate historical attributes
- Replace invalid values with defaults

===============================================================================
Recommended Workflow
-------------------------------------------------------------------------------

       Bronze Layer
             │
             ▼
     Data Profiling
             │
             ▼
  Data Quality Assessment
             │
             ▼
  Identify Data Issues
             │
             ▼
  Define Transformation Rules
             │
             ▼
       Silver Layer
             │
             ▼
  Clean & Standardized Data																									*/

-----------------------------------
-- Discover crm_Cust_Info Problems:
-----------------------------------

--> Nulls value in cst_ID
select * from bronze.crm_cust_info
where cst_id is null		-- 3 Null values

--> Duplicated cst_ID
select cst_id , count(*)
from bronze.crm_cust_info
group by cst_id
having count(*) >1  

select cst_key , count(*)
from bronze.crm_cust_info
group by cst_key
having count(*) >1			-- Duplicated cst_id & cst_key 

--> Check categorial fields:
select distinct c.cst_gndr
from bronze.crm_cust_info c  -- Null , F , M

select distinct c.cst_marital_status
from bronze.crm_cust_info c  -- Null , S , M

--> Check Text Quality:
select *
from bronze.crm_cust_info c
where c.cst_firstname != trim(c.cst_firstname)
or c.cst_lastname != trim(c.cst_lastname)

--> Check Date columns:
select *
from bronze.crm_cust_info c
where cst_create_date > GETDATE() -- no error in dates

-------------------------------------------------------
-- Solve these problems :
------------------------
INSERT INTO silver.crm_cust_info 
			   (cst_id, 
				cst_key, 
				cst_firstname, 
				cst_lastname, 
				cst_marital_status, 
				cst_gndr,
				cst_create_date)
SELECT cst_id,
	   cst_key,
	   TRIM(cst_firstname) AS cst_firstname,
	   TRIM(cst_lastname) AS cst_lastname,
	   CASE TRIM(cst_marital_status) 
		   WHEN 'S' THEN 'Single'					   
		   WHEN 'M' THEN 'Married'
		   ELSE 'n/a'
	   END AS cst_marital_status,
	   CASE TRIM(cst_gndr) 
		   WHEN 'S' THEN 'Single'					   
		   WHEN 'M' THEN 'Married'
		   ELSE 'n/a'
	   END AS cst_gndr
FROM (SELECT 
		*,
		Row_Number()over(partition by cst_id order by cst_create_date desc ) AS flag_last
	  FROM bronze.crm_cust_info
	  ) AS t
	  WHERE flag_last=1
	  AND   cst_id is not null 
	  
-----------------------------------
-- Discover crm_prd_Info Problems :
-----------------------------------

select * from bronze.crm_prd_info
where prd_id is null or prd_id = ''  
--> No Null  Values ✔️✔️✔️

select prd_key,count(*) AS duplicated
from bronze.crm_prd_info
group by prd_key
having COUNT(*) >1   
--> Duplicated prd_key (No prd_id)

select * from bronze.crm_prd_info
where prd_cost is null or prd_id = '' or prd_cost=0  
--> Null values in cost ✔️✔️✔️

select * from bronze.crm_prd_info
where prd_nm != trim(prd_nm)
--> No wrong  values ✔️✔️✔️

select * from bronze.crm_prd_info
where prd_start_dt > prd_end_dt
--> 200 Row with wrong values

select distinct prd_line 
from bronze.crm_prd_info
--> replace values and Nulls


-------------------------------------------------------
-- Solve these problems :
------------------------
INSERT INTO silver.crm_prd_info (
					prd_id,
					cat_id,
					prd_key,
					prd_nm,
					prd_cost,
					prd_line,
					prd_start_dt,
					prd_end_dt )
SELECT  prd_id,																				
		SUBSTRING(prd_key,7,LEN(prd_key)) AS prd_key,
		SUBSTRING(prd_key,1,5) AS cat_id,
		TRIM(prd_nm) AS prd_name,
		isnull(prd_cost,0) AS prd_cost,
		CASE UPPER(TRIM(prd_line))
			WHEN 'M' THEN 'Mountain'
			WHEN 'R' THEN 'Road'
			WHEN 'S' THEN 'Other Sales'
			WHEN 'T' THEN 'Touring'
			ELSE 'n/a'
		END AS prd_line,
		CAST(prd_start_dt AS DATE) AS prd_start_dt,
		CAST( (lead(prd_start_dt)over(partition by prd_key order by prd_start_dt ) -1 ) AS DATE ) AS prd_end_dt
FROM bronze.crm_prd_info ;

---------------------------------------
-- Discover crm_sales_details Problems :
---------------------------------------
select sls_ord_num,count(*)
from bronze.crm_sales_details
group by sls_ord_num
having count(*) >1 
--> ❌❌

select * from bronze.crm_sales_details
where sls_ord_num is null or sls_ord_num = ''
--> No Null values or empty  ✔️✔️✔️

select * from bronze.crm_sales_details
where sls_order_dt > sls_ship_dt 
   or sls_ship_dt > sls_due_dt
   or len(sls_order_dt)!=8
   or len(sls_ship_dt)!=8
   or len(sls_due_dt)!=8
--> errorsin length ❌

select * from bronze.crm_sales_details
where sls_sales != (sls_price*sls_quantity) 
--> errors ❌

select * from bronze.crm_sales_details
where sls_sales is null 
	or sls_sales<=0 
	or sls_sales = '' 
--> errors ❌

select * from bronze.crm_sales_details
where sls_quantity is null 
	or sls_quantity<=0 
	or sls_quantity = '' 
--> Quantaties are correct ✔️✔️✔️

select * from bronze.crm_sales_details
where sls_price is null 
	or sls_price<=0 
	or sls_price = '' 
--> errors ❌

select * from bronze.crm_sales_details
where sls_prd_key not in 
(select distinct p.prd_key from silver.crm_prd_info p )
--> No prd_keys wrong ✔️✔️✔️

select * from bronze.crm_sales_details
where sls_cust_id not in 
(select distinct c.cst_id from bronze.crm_cust_info c )
--> No cst_id wrong ✔️✔️✔️

-------------------------------------------------------
-- Solve these problems :
------------------------
INSERT INTO silver.crm_sales_details (
		sls_ord_num,
		sls_prd_key,
		sls_cust_id,
		sls_order_dt,
		sls_ship_dt,
		sls_due_dt,
		sls_sales,
		sls_quantity,
		sls_price )

SELECT  sls_ord_num,
		sls_prd_key,
		sls_cust_id,

		CASE 
			WHEN LEN(sls_order_dt)=8 THEN CAST(CAST(sls_order_dt as varchar) as DATE )
			ELSE NULL 
		END as sls_order_dt,

		CASE 
			WHEN LEN(sls_ship_dt)=8 THEN CAST(CAST(sls_ship_dt as varchar) as DATE )
			ELSE NULL 
		END as sls_ship_dt,

		CASE 
			WHEN LEN(sls_due_dt)=8 THEN CAST(CAST(sls_due_dt as varchar) as DATE )
			ELSE NULL 
		END as sls_due_dt,

		CASE 
			WHEN sls_sales is null or sls_sales <=0 or sls_sales != (sls_quantity *sls_price )
				THEN sls_quantity*abs(sls_price)
			ELSE sls_sales
		END AS sls_sales,

		sls_quantity,	

		CASE 
			WHEN sls_price is null or sls_price <=0 
				THEN sls_price/NULLIF(sls_quantity,0)
			ELSE sls_price 
		END AS sls_price
FROM bronze.crm_sales_details


select * from bronze.crm_sales_details
where len(sls_order_dt)!=8

---------------------------------------
-- Discover erp_cust_az12 Problems :
---------------------------------------

--> Error in cst_key  

select cid,count(*)
from bronze.erp_cust_az12
group by cid
having count(*) >1 ;
--> No Duplicated IDs

select substring(cid,4,len(cid))
from bronze.erp_cust_az12
where substring(cid,4,len(cid)) not in 
(select distinct cst_key
from bronze.crm_cust_info)


select * from 
bronze.erp_cust_az12
where bdate > getdate()
--> Errors in Dates  (16 records)


select distinct gen 
from bronze.erp_cust_az12  
--> Errors : Null , F, empty ,Male Female ,M 

-------------------------------------------------------
-- Solve these problems :
------------------------
INSERT INTO silver.erp_cust_az12 (
			cid,
			bdate,
			gen
		)
SELECT 
	   CASE
		   WHEN cid like 'NAS%' THEN substring(cid,4,len(cid))
		   ELSE cid
	   END AS cid,

	   CASE
		   WHEN bdate > getdate() THEN NUll
		   ELSE bdate
	   END AS bdate,

	   CASE
		   WHEN TRIM(gen) IN ('F', 'Female') THEN 'Female'
		   WHEN TRIM(gen) IN ('M', 'Male') THEN 'Male'
		   ELSE 'n/a'
	   END
FROM bronze.erp_cust_az12  

-----------------------------------
-- Discover erp_loc_a101 Problems :
-----------------------------------

--> Error in cst_key  

select cid,count(*)
from bronze.erp_loc_a101
group by cid
having count(*) >1 ;
--> No Duplicated IDs

select replace(cid,'-','')
from bronze.erp_loc_a101
where replace(cid,'-','') not in 
(select distinct cst_key
from bronze.crm_cust_info)
--> refrential integrity OK ✔️

select distinct cntry 
from bronze.erp_loc_a101  
--> Errors : USA,United States,US     DE,Germany   NUll   empty

-------------------------------------------------------
-- Solve these problems :
------------------------
INSERT INTO silver.erp_loc_a101 (
	cid,
	cntry)

SELECT
	REPLACE(cid, '-', '') AS cid, 
	CASE
		WHEN TRIM(cntry) = 'DE' THEN 'Germany'
		WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
		WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
		ELSE TRIM(cntry)
	END AS cntry 
FROM bronze.erp_loc_a101;

-----------------------------------
-- Discover erp_px_cat_g1v2 Problems :
-----------------------------------
select id,count(*)
from bronze.erp_px_cat_g1v2
group by id
having count(*) >1 ;
--> No Duplicated IDs ✔️

select distinct cat from bronze.erp_px_cat_g1v2
--> Categories are Okey ✔️

select distinct subcat from bronze.erp_px_cat_g1v2
--> Sub-Categories are Okey ✔️

select distinct maintenance from bronze.erp_px_cat_g1v2
--> maintenance are Okey ✔️

INSERT INTO 
	silver.erp_px_cat_g1v2 (
	id,
	cat,
	subcat,
	maintenance)

SELECT
	id,
	cat,
	subcat,
	maintenance
FROM bronze.erp_px_cat_g1v2;