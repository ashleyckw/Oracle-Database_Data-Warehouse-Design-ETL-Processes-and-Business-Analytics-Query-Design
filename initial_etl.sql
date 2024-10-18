SET LINESIZE 200
SET PAGESIZE 100

---- DATE DIMENSION ----------------------------------------------------------------------------------------------
-- Drop Sequence of Date Dimension
DROP SEQUENCE date_seq;

-- Create Sequence to Insert into Date Dimension
CREATE SEQUENCE date_seq 
START WITH 100001
INCREMENT BY 1;

-- Drop the Date Dimension
DROP TABLE dim_date;

-- Create the Date Dimension
CREATE TABLE dim_date (
	date_key              	NUMBER 		NOT NULL,	
	calendar_date         	DATE 		NOT NULL,
	day_of_week          	NUMBER(1) 	NOT NULL,
	day_of_month     		NUMBER(2) 	NOT NULL,
	day_of_year      		NUMBER(3) 	NOT NULL,
	last_day_in_month_ind 	CHAR(1),
	cal_week_end_date     	DATE 		NOT NULL,
	cal_week_no_in_year     NUMBER(2) 	NOT NULL,
	cal_month_name        	VARCHAR(9) 	NOT NULL,
	cal_month_no_in_year  	NUMBER(2) 	NOT NULL,
	cal_year_month        	CHAR(7) 	NOT NULL,
	cal_quarter           	CHAR(2) 	NOT NULL,
	cal_year_quarter      	CHAR(6) 	NOT NULL,
	cal_year              	NUMBER(4) 	NOT NULL,
	holiday_ind          	CHAR(1),
	weekday_ind          	CHAR(1),
	PRIMARY KEY (date_key)
);

-- Insert Data into Date Dimension
DECLARE
   every_date         DATE;
   end_date           DATE;
   v_day_of_week      NUMBER(1);
   v_day_of_month     NUMBER(2);
   v_day_of_year      NUMBER(3);
   last_day_month_ind CHAR(1);
   v_week_end_date    DATE;
   v_week_in_year     NUMBER(2);
   v_month_name       VARCHAR(9);
   v_month_no         NUMBER(2);
   v_year_month       CHAR(7);
   v_quarter          CHAR(2);
   v_year_quarter     CHAR(6); 
   v_year             NUMBER(4);
   v_holiday_ind      CHAR(1);
   v_weekday_ind      CHAR(1);

BEGIN
   every_date     := TO_DATE('01/06/2013','dd/mm/yyyy');
   end_date       := TO_DATE('01/06/2023','dd/mm/yyyy');
   v_holiday_ind  :='N';

   WHILE (every_date <= end_date) LOOP
      v_day_of_week    := TO_CHAR(every_date,'D');
      v_day_of_month   := TO_CHAR(every_date,'DD');
      v_day_of_year    := TO_CHAR(every_date,'DDD');

      IF every_date = Last_Day(every_date) THEN
        last_day_month_ind := 'Y';
      END IF;

      v_week_end_date  := every_date+(7-(TO_CHAR(every_date,'d')));
  
      v_week_in_year   := TO_CHAR(every_date,'IW');
      v_month_name     := TO_CHAR(every_date,'MONTH');
      v_month_no       := EXTRACT (MONTH FROM every_date);
      v_year_month     := TO_CHAR(every_date,'YYYY-MM');

      IF (v_month_no<=3) THEN
         v_quarter := 'Q1';
      ELSIF (v_month_no<=6) THEN
         v_quarter := 'Q2';
      ELSIF (v_month_no<=9) THEN
         v_quarter := 'Q3';
      ELSE
         v_quarter := 'Q4';
      END IF;

      v_year          := EXTRACT (year FROM every_date);
      v_year_quarter  := v_year||v_quarter;

      IF (v_day_of_week BETWEEN 2 AND 6) THEN
         v_weekday_ind := 'Y';
      ELSE
         v_weekday_ind := 'N';
      END IF;
      
      INSERT INTO dim_date VALUES (date_seq.NEXTVAL,
                                  every_date,
                                  v_day_of_week,
                                  v_day_of_month,
                                  v_day_of_year,
                                  last_day_month_ind,
                                  v_week_end_date,
                                  v_week_in_year,
                                  v_month_name,
                                  v_month_no,
                                  v_year_month,
                                  v_quarter,
                                  v_year_quarter, 
                                  v_year,
                                  v_holiday_ind,
                                  v_weekday_ind
                                 );
      every_date := every_date + 1;
   END LOOP;
END;
/

-- OUTPUT: PL/SQL procedure successfully completed.

-- Examine the Date Dimension table
SELECT * FROM dim_date;

-- Check the Date Dimension table structure
DESC dim_date;


---- PRODUCT DIMENSION ------------------------------------------------------------------------------------------
-- Drop Sequence of Product Dimension
DROP SEQUENCE prod_seq;

-- Create Sequence to Insert into Product Dimension
CREATE SEQUENCE prod_seq
START WITH 1001
INCREMENT BY 1;

-- Drop the Product Dimension
DROP TABLE dim_products;

-- Create the Product Dimension
CREATE TABLE dim_products (
	product_key 		NUMBER 			NOT NULL,
	product_id 			NUMBER 			NOT NULL,
	product_name 		VARCHAR2(50)	NOT NULL,
	product_description	VARCHAR2(2000),
	product_category 	VARCHAR2(255)	NOT NULL,
	PRIMARY KEY (product_key)
);

-- Insert Data into Product Dimension
INSERT INTO dim_products (product_key, product_id, product_name, product_description, product_category)
SELECT prod_seq.NEXTVAL, 
		p.product_id, 
		UPPER(p.product_name), 
		UPPER(p.description), 
		UPPER(pc.category_name)
FROM products p 
INNER JOIN product_categories pc 
	ON p.category_id = pc.category_id;

-- OUTPUT: 288 rows inserted.

-- Examine the Product Dimension table
SELECT * FROM dim_products;

-- Check number of records, should be 288
SELECT COUNT(*) FROM dim_products;

-- Check the Product Dimension table structure
DESC dim_products;


---- CUSTOMER DIMENSION ------------------------------------------------------------------------------------------
-- Drop Sequence of Customer Dimension
DROP SEQUENCE cust_seq;

-- Create Sequence to Insert into Customer Dimension
CREATE SEQUENCE cust_seq
START WITH 10000001
INCREMENT BY 1;

-- Drop the Customer Dimension
DROP TABLE dim_customers;

-- Create the Customer Dimension
CREATE TABLE dim_customers (
	customer_key 			NUMBER 			NOT NULL,
	customer_id				NUMBER 			NOT NULL,
	customer_name			VARCHAR2(50)	NOT NULL,
	first_name 				VARCHAR2(255)	NOT NULL,
	last_name 				VARCHAR2(255)	NOT NULL,
	address					VARCHAR2(255)	NOT NULL,
	credit_limit 			NUMBER(8,2),
	customer_status			VARCHAR(50)		NOT NULL,
	customer_geography 		VARCHAR(50),
	PRIMARY KEY (customer_key)
);

-- Insert Data into the Customer Dimension
INSERT INTO dim_customers (
	SELECT cust_seq.NEXTVAL, sub.* 
	FROM (SELECT 
			c.customer_id, 
			UPPER(c.name), 
			UPPER(s.first_name), 
			UPPER(s.last_name), 
			UPPER(c.address), 
			c.credit_limit, 
			CASE
				WHEN MAX(o.order_date) < ADD_MONTHS('31-DEC-17', -12) OR MAX(o.order_date) IS NULL THEN 'INACTIVE'
				ELSE 'ACTIVE'
			END AS customer_status, 
			CASE 
				WHEN c.address LIKE '%,%,%' THEN SUBSTR(UPPER(c.address), INSTR(UPPER(c.address), ',', 1, 2) + 1) 
				ELSE NULL
			END AS customer_geography
	FROM customers c
	LEFT JOIN contacts s 
		ON c.customer_id = s.customer_id
	LEFT JOIN orders o 
		ON c.customer_id = o.customer_id
	GROUP BY c.customer_id, c.name, s.first_name, s.last_name, c.address, c.credit_limit
	) sub
);

-- OUTPUT: 319 rows inserted.

-- Examine the Customer Dimension table
SELECT * FROM dim_customers;

-- Check number of records, should be 319
SELECT COUNT(*) FROM dim_customers;

-- Check the Customer Dimension table structure
DESC dim_customers;


---- COUNTRY DIMENSION ------------------------------------------------------------------------------------------
-- Drop Sequence of Country Dimension
DROP SEQUENCE countries_seq;

-- Create Sequence to Insert into Country Dimension
CREATE SEQUENCE countries_seq
START WITH 101
INCREMENT BY 1;

-- Drop the Country Dimension
DROP TABLE dim_countries;

-- Create the Country Dimension
CREATE TABLE dim_countries (
    country_key 	NUMBER 			NOT NULL,
	country_id 		CHAR(2)			NOT NULL,
	country_name 	VARCHAR2(40)	NOT NULL,
    region_name 	VARCHAR2(50)	NOT NULL,
	PRIMARY KEY (country_key)
);

-- Insert Data into the Country Dimension
INSERT INTO dim_countries (country_key, country_id, country_name, region_name)
SELECT countries_seq.NEXTVAL,
	UPPER(ct.country_id),
    UPPER(ct.country_name),
    UPPER(r.region_name)
FROM countries ct
JOIN regions r 
	ON ct.region_id = r.region_id;

-- OUTPUT: 25 rows inserted.

-- Examine the Country Dimension table
SELECT * FROM dim_countries;

-- Check number of records, should be 25
SELECT COUNT(*) FROM dim_countries;

-- Check the Country Dimension table structure
DESC dim_countries;


---- WAREHOUSE DIMENSION ------------------------------------------------------------------------------------------
-- Drop Sequence of Warehouse Dimension
DROP SEQUENCE wareh_seq;

-- Create Sequence to Insert into Warehouse Dimension
CREATE SEQUENCE wareh_seq
START WITH 10001
INCREMENT BY 1;

-- Drop Warehouse Dimension
DROP TABLE dim_warehouses;

-- Create Warehouse Dimension
CREATE TABLE dim_warehouses (
	warehouse_key 	NUMBER 			NOT NULL,
	warehouse_id 	NUMBER 			NOT NULL,
	warehouse_name	VARCHAR2(255)	NOT NULL,
	address			VARCHAR2(255)	NOT NULL,
	postal_code		VARCHAR2(20),
	city 			VARCHAR2(50) 	NOT NULL,
	state			VARCHAR2(50) 	NOT NULL,
	country_key  	NUMBER          NOT NULL,
	PRIMARY KEY (warehouse_key),
	CONSTRAINT fk_country FOREIGN KEY (country_key)
		REFERENCES dim_countries(country_key)
		ON DELETE CASCADE
);

-- Insert Data into the Warehouse Dimension
INSERT INTO dim_warehouses (warehouse_key, warehouse_id, warehouse_name, address, postal_code, city, state, country_key)
SELECT wareh_seq.NEXTVAL, 
	w.warehouse_id,
    UPPER(w.warehouse_name),
    UPPER(l.address),
    UPPER(l.postal_code),
    UPPER(l.city),
    COALESCE(UPPER(l.state), UPPER(l.city)) AS state, -- if the state is a NULL value, this function returns the city as the state
	dct.country_key
FROM warehouses w
JOIN locations l 
	ON w.location_id = l.location_id
JOIN dim_countries dct 
	ON l.country_id = dct.country_id;

-- OUTPUT: 9 rows inserted.

-- Examine the Warehouse Dimension table
SELECT * FROM dim_warehouses;

-- Check number of records, should be 9
SELECT COUNT(*) FROM dim_warehouses;

-- Check the Warehouse Dimension table structure
DESC dim_warehouses;


---- EMPLOYEE DIMENSION ------------------------------------------------------------------------------------------
-- Drop Sequence of Employee Dimension
DROP SEQUENCE employ_seq;

-- Create Sequence to Insert into Employee Dimension
CREATE SEQUENCE employ_seq
START WITH 1000001
INCREMENT BY 1;

-- Drop Employee Dimension
DROP TABLE dim_employees;

-- Create Employee Dimension
CREATE TABLE dim_employees (
    employee_key 		NUMBER 			NOT NULL,
	employee_id 		NUMBER 			NOT NULL,
	first_name 			VARCHAR(255) 	NOT NULL,
	last_name 			VARCHAR(255) 	NOT NULL,
	email 				VARCHAR(255) 	NOT NULL,
	phone 				VARCHAR(50) 	NOT NULL,
	hire_date			DATE,
	no_of_days_employed NUMBER,
	job_title		 	VARCHAR(255) 	NOT NULL,
	PRIMARY KEY (employee_key)
);

-- Insert Data into the Employee Dimension
INSERT INTO dim_employees (employee_key, employee_id, first_name, last_name, email, phone, hire_date, no_of_days_employed, job_title)
SELECT employ_seq.NEXTVAL,
	emp.employee_id,
    UPPER(emp.first_name),
    UPPER(emp.last_name),
    emp.email,
    UPPER(emp.phone),
    emp.hire_date,
    TRUNC(SYSDATE - emp.hire_date), -- Calculate the number of days employed
    UPPER(emp.job_title)
FROM employees emp;

-- OUTPUT: 107 rows inserted.

-- Examine the Employee Dimension table
SELECT * FROM dim_employees;

-- Check number of records, should be 107
SELECT COUNT(*) FROM dim_employees;

-- Check the Employee Dimension table structure
DESC dim_employees;


---- SALES FACT ---------------------------------------------------------------------------------------------------
-- Drop Sales Fact Table
DROP TABLE sales_fact;

-- Create Sales Fact Table
CREATE TABLE sales_fact (
	date_key			NUMBER			NOT NULL,
	product_key			NUMBER			NOT NULL,
	customer_key		NUMBER			NOT NULL,
	employee_key		NUMBER,
	order_id			NUMBER			NOT NULL,
	order_status		VARCHAR(20) 	NOT NULL,
    order_date 			DATE 			NOT NULL,
	item_quantity 		NUMBER(8,2)		NOT NULL,
	standard_cost		NUMBER(9,2),
    unit_price 			NUMBER(8,2)		NOT NULL,
	unit_profit			NUMBER(8,2),
	order_total_price	NUMBER(8,2),
	gross_profit		NUMBER(8,2),
	CONSTRAINT sales_fk_dates FOREIGN KEY (date_key)
		REFERENCES dim_date(date_key)
		ON DELETE CASCADE,
	CONSTRAINT sales_fk_products FOREIGN KEY (product_key)
		REFERENCES dim_products(product_key)
		ON DELETE CASCADE,
	CONSTRAINT sales_fk_customers FOREIGN KEY (customer_key)
		REFERENCES dim_customers(customer_key)
		ON DELETE CASCADE,
	CONSTRAINT sales_fk_employees FOREIGN KEY (employee_key)
		REFERENCES dim_employees(employee_key)
		ON DELETE CASCADE
);

-- Insert Data into the Sales Fact
INSERT INTO sales_fact (date_key, product_key, customer_key, employee_key, order_id, order_status, order_date, item_quantity, standard_cost, unit_price, unit_profit, order_total_price, gross_profit) 
SELECT dd.date_key,
		dp.product_key, 
		dc.customer_key, 
		de.employee_key,	-- NVL(de.employee_key, 9999999) as employee_key,
		o.order_id,
		UPPER(o.status), 
		o.order_date, 
		oi.quantity,
		p.standard_cost,		
		oi.unit_price, 
		oi.unit_price - p.standard_cost AS unit_profit, 
		oi.quantity * oi.unit_price AS order_total_price,
		oi.quantity * (oi.unit_price - p.standard_cost) AS gross_profit
FROM dim_date dd
JOIN orders o 
	ON TRUNC(dd.calendar_date) = TRUNC(o.order_date)
JOIN order_items oi
	ON o.order_id = oi.order_id
JOIN dim_products dp 
	ON oi.product_id = dp.product_id
JOIN products p
	ON oi.product_id = p.product_id
JOIN dim_customers dc 
	ON o.customer_id = dc.customer_id
LEFT JOIN dim_employees de 
	ON o.salesman_id = de.employee_id;

-- NOTE: 404 rows inserted (without null values in employee.id (salesman_id)).
-- OUTPUT: 665 rows inserted (with null values in employee.id that will later on be replaced with dummy employee records).

-- Examine the Sales Fact table
SELECT * FROM sales_fact;

-- Check number of records, should be 665
SELECT COUNT(*) FROM sales_fact;

-- Check the Sales Fact table structure
DESC sales_fact;
	
-- Update the dim_employees with dummy employee records for orders in orders table with NULL values. 
INSERT INTO dim_employees VALUES (9999999, 9999, 'UNDEFINED', 'UNDEFINED', 'UNDEFINED', 'UNDEFINED', NULL, 0, 'UNDEFINED');

UPDATE sales_fact
SET employee_key = 9999999
WHERE employee_key IS NULL;

-- Examine the Sales Fact table once again (with dummy employee records in employee_key)
SELECT * FROM sales_fact;


---- INVENTORY FACT ---------------------------------------------------------------------------------------------------
-- Drop Inventory Fact Table
DROP TABLE inventories_fact;

-- Create Inventory Fact Table
CREATE TABLE inventories_fact (
	product_key 		NUMBER		NOT NULL,
	warehouse_key 		NUMBER		NOT NULL,
	inventory_quantity 	NUMBER(4)	NOT NULL,
	standard_cost		NUMBER(9,2),
	list_price			NUMBER(9,2),
	CONSTRAINT inventory_fk_products FOREIGN KEY (product_key)
		REFERENCES dim_products(product_key)
		ON DELETE CASCADE,
	CONSTRAINT inventory_fk_warehouses FOREIGN KEY (warehouse_key)
		REFERENCES dim_warehouses(warehouse_key)
		ON DELETE CASCADE
);
	
-- Insert Data into the Inventory Fact
INSERT INTO inventories_fact (product_key, warehouse_key, inventory_quantity, standard_cost, list_price)
SELECT dp.product_key,
		dw.warehouse_key,
		i.quantity,
		p.standard_cost, 
		p.list_price
FROM products p
JOIN dim_products dp 
	ON p.product_id = dp.product_id
JOIN inventories i 
	ON dp.product_id = i.product_id
JOIN warehouses w
	ON i.warehouse_id = w.warehouse_id
JOIN dim_warehouses dw 
	ON w.warehouse_id = dw.warehouse_id;
		
-- OUTPUT: 1,112 rows inserted.

-- Examine the Inventory Fact table
SELECT * FROM inventories_fact;

-- Check number of records, should be 1,112
SELECT COUNT(*) FROM inventories_fact;

-- Check the Inventory Fact table structure
DESC inventories_fact;