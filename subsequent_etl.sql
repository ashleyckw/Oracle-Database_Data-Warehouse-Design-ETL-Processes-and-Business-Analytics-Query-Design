-- To enable DBMS_OUTPUT and set the buffer size
SET SERVEROUTPUT ON;

-- Function for Secure Subsequent Updates
CREATE OR REPLACE FUNCTION secure_dml RETURN BOOLEAN
IS
BEGIN
  IF TO_CHAR (SYSDATE, 'HH24:MI') NOT BETWEEN '08:00' AND '09:00' 
    OR TO_CHAR(SYSDATE, 'DY') IN ('SAT', 'SUN') THEN
      DBMS_OUTPUT.PUT_LINE('Error! Updates are not allowed outside of office hours: '||TO_CHAR (SYSDATE, 'HH24:MI'));
      RETURN FALSE;
    ELSE
      DBMS_OUTPUT.PUT_LINE(TO_CHAR (SYSDATE, 'HH24:MI') || ' ' || TO_CHAR(SYSDATE, 'DY') || '. Congratulations. You may proceed.');
      RETURN TRUE;
  END IF;
END;
/

---- DATE DIMENSION -----------------------------------------------------------------------------------------------

/*
	1. Update subsequent/new dates into the Date Dimension Table
*/
-- Insert Data into Date Dimension
CREATE OR REPLACE PROCEDURE prc_dim_date (start_date IN DATE, new_end_date IN DATE) IS

   -- Variable Declaration
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
   -- Initialize the start date, end date and holiday to 'N'
   every_date     := TO_DATE(start_date,'dd/mm/yyyy');
   end_date       := TO_DATE(new_end_date,'dd/mm/yyyy');
   v_holiday_ind  :='N';

   -- Loop while the date is within every_date and end_date
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
      
	  -- Write Data into the Date Dimension Table
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

-- Alter the session to a Date Format of 'DD/MM/YYYY'
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- Execute the Date Dimension Procedure
EXEC prc_dim_date('01/01/2017','01/01/2018');

-- Examine the Date Dimension table
SELECT * FROM dim_date;

-- Check the Date Dimension table structure
DESC dim_date;


/*
	2. Type 1 Slowly Changing Dimension technique: Update Holidays Procedure
*/
-- Update the Date Dimension to mark certain dates declared as holidays
CREATE OR REPLACE PROCEDURE update_holidays_prc (prc_date DATE) IS
	  
	  is_update_allowed BOOLEAN;

BEGIN
    
   -- Call secure_dml function to check if update is allowed
   is_update_allowed := secure_dml;
   
   IF NOT is_update_allowed THEN
		RETURN;
   END IF;
  
   -- Update the Record
   UPDATE dim_date
   SET holiday_ind = 'Y'
   WHERE calendar_date = prc_date;

   -- Display Message Indicating Successful Update
   IF SQL%FOUND THEN
      DBMS_OUTPUT.PUT_LINE('Input Date: '|| prc_date ||' has been updated as a Holiday in the dim_date table.');
   ELSE
   	  -- Display Error Message
      DBMS_OUTPUT.PUT_LINE('ERROR! No such date in database.');
   END IF;
END;
/

-- Alter the session to a Date Format of 'DD/MM/YYYY'
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- Execute the Update Holidays Procedure
EXEC update_holidays_prc('25/12/2016')


---- PRODUCT DIMENSION --------------------------------------------------------------------------------------------

/*
	1. Update new products into the Product Dimension Table
*/
-- Insert Data into Product Dimension
INSERT INTO dim_products (product_key, product_id, product_name, product_description, product_category)
SELECT prod_seq.NEXTVAL, 
		p.product_id, 
		UPPER(p.product_name), 
		UPPER(p.description), 
		UPPER(pc.category_name)
FROM products p 
INNER JOIN product_categories pc 
	ON p.category_id = pc.category_id
WHERE product_id NOT IN (SELECT product_id FROM dim_products);

-- Examine the Product Dimension table
SELECT * FROM dim_products;

-- Check number of records
SELECT COUNT(*) FROM dim_products;

-- Check the Product Dimension table structure
DESC dim_products;

/*
-- Create a trigger to fire on insert, update, and delete operations on the products table
CREATE OR REPLACE TRIGGER update_dim_products_trg
AFTER INSERT OR UPDATE OR DELETE ON products
FOR EACH ROW
BEGIN
  -- Call the stored procedure to update the dim_products table
  update_dim_products_prc;
END;
/

-- Create a stored procedure to update the dim_products table
CREATE OR REPLACE PROCEDURE update_dim_products_prc
IS
BEGIN
    -- Insert the latest information from the products table into the dim_products table
    INSERT INTO dim_products (product_key, product_id, product_name, product_description, product_category)
    SELECT prod_seq.NEXTVAL, 
            p.product_id, 
            UPPER(p.product_name), 
            UPPER(p.description), 
            UPPER(pc.category_name)
    FROM products p 
    INNER JOIN product_categories pc 
        ON p.category_id = pc.category_id
    WHERE product_id NOT IN (SELECT product_id FROM dim_products);
END;
/

Insert into PRODUCTS (PRODUCT_ID,PRODUCT_NAME,DESCRIPTION,STANDARD_COST,LIST_PRICE,CATEGORY_ID) values (290,'Samsung ASS-75E500B/AM','Series:1050 EVO-Series,Type:SSD,Capacity:850GB,Cache:8MB',150.50,180.50,5);

*/


/*
	2. Type 2 Slowly Changing Dimension technique: Update Products Procedure
*/
-- Alter the session to a Date Format of 'DD/MM/YYYY'
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- Alter the Products Dimension to add start_date, end_date and products_active_flag column
ALTER TABLE dim_products  
	ADD start_date DATE DEFAULT '01/01/2017' NOT NULL;
ALTER TABLE dim_products  
	ADD end_date DATE DEFAULT '31/12/9999' NOT NULL;
ALTER TABLE dim_products  
	ADD products_active_flag CHAR(1) DEFAULT 'Y' NOT NULL;
	
-- Procedure to update the Products Dimension
CREATE OR REPLACE PROCEDURE update_product_prc (prc_product_id IN NUMBER, prc_start_date IN DATE) IS
	
	-- Curser to get the Product Details
	CURSOR prod_cur IS
        SELECT product_key, product_id, product_name, product_description, product_category, start_date, end_date, products_active_flag
        FROM dim_products 
        WHERE product_id = prc_product_id;
    
	prod_rec prod_cur%ROWTYPE;
	
	-- Variable Declaration
	is_update_allowed BOOLEAN;
	prod_count NUMBER;
	
BEGIN

	-- Call secure_dml function to check if update is allowed
	is_update_allowed := secure_dml;
   
	IF NOT is_update_allowed THEN
		RETURN;
	END IF;
	
	-- Check if product exists
	SELECT COUNT(*) INTO prod_count
    FROM dim_products
    WHERE product_id = prc_product_id;
    
	-- Handle Exception when no records are found
    IF prod_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Product ID '||prc_product_id||' does not exist. Please re-enter Product ID.');
    END IF;
	
	-- Open Cursor
	OPEN prod_cur;
	
	-- Loop and Fetch the Records
	LOOP
		FETCH prod_cur INTO prod_rec;
		EXIT WHEN prod_cur%NOTFOUND;
			
		-- Update the Record
		UPDATE dim_products 
		SET end_date = prc_start_date - 1,
			products_active_flag = 'N'
		WHERE product_key = prc_product_id;
			
		-- Write Data into the Product Dimension Table
		INSERT INTO dim_products  (
			product_key, 
			product_id, 
			product_name, 
			product_description, 
			product_category,
			start_date,
			end_date,
			products_active_flag
		) VALUES (
			prod_seq.NEXTVAL,
			prc_product_id,
			prod_rec.product_name,
			prod_rec.product_description,
			prod_rec.product_category,
			prc_start_date,
			'31/12/9999',
			'Y'
		);
			
		-- Display Message Indicating Successful Update
		DBMS_OUTPUT.PUT_LINE(
			'Product with Product ID of ' || prc_product_id || ' updated successfully!' || CHR(10) || 
			'Start Date = ' || TO_CHAR(prc_start_date, 'DD/MM/YYYY')
		);
	END LOOP;
	
	-- Close Cursor
    CLOSE prod_cur;
	
-- Exception when no records are found
EXCEPTION
	WHEN OTHERS THEN
		-- Display Error Message
		DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/

-- Execute the Update Products Procedure
EXEC update_product_prc (17, '24/12/2018')

-- Examine the Products Dimension table for the new row
SELECT * FROM dim_products;


---- CUSTOMER DIMENSION -------------------------------------------------------------------------------------------

/*
	1. Update new customers into the Customer Dimension Table
*/
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
				WHEN MAX(o.order_date) < ADD_MONTHS('31-DEC-16', -12) OR MAX(o.order_date) IS NULL THEN 'INACTIVE'
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
	WHERE customer_id NOT IN (SELECT customer_id FROM dim_customers)
);

-- Examine the Customer Dimension table
SELECT * FROM dim_customers;

-- Check number of records
SELECT COUNT(*) FROM dim_customers;

-- Check the Customer Dimension table structure
DESC dim_customers;


/*
	2. Type 2 Slowly Changing Dimension technique: Update Customer Procedure
*/
-- Alter the session to a Date Format of 'DD/MM/YYYY'
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- Alter the Customer Dimension to add start_date, end_date and customer_active_flag column
ALTER TABLE dim_customers  
	ADD start_date DATE DEFAULT '01/01/2017' NOT NULL;
ALTER TABLE dim_customers 
	ADD end_date DATE DEFAULT '31/12/9999' NOT NULL;
ALTER TABLE dim_customers 
	ADD customer_active_flag CHAR(1) DEFAULT 'Y' NOT NULL;
	
-- Procedure to update the Customer Dimension
CREATE OR REPLACE PROCEDURE update_customer_prc (prc_customer_id IN NUMBER, prc_start_date IN DATE) IS
	
	-- Curser to get the Customer Details
	CURSOR cust_cur IS
        SELECT customer_key, customer_id, customer_name, first_name, last_name, address, credit_limit, customer_status, customer_geography, start_date, end_date, customer_active_flag
        FROM dim_customers
        WHERE customer_id = prc_customer_id;
    
	cust_rec cust_cur%ROWTYPE;
	
	-- Variable Declaration
	is_update_allowed BOOLEAN;
	cust_count NUMBER;
	
BEGIN

	-- Call secure_dml function to check if update is allowed
	is_update_allowed := secure_dml;
   
	IF NOT is_update_allowed THEN
		RETURN;
	END IF;
	
	-- Check if customer exists
	SELECT COUNT(*) INTO cust_count
    FROM dim_customers
    WHERE customer_id = prc_customer_id;
    
	-- Handle Exception when no records are found
    IF cust_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Customer ID '||prc_customer_id||' does not exist. Please re-enter Customer ID.');
    END IF;
	
	-- Open Cursor
	OPEN cust_cur;
	
	-- Loop and Fetch the Records
	LOOP
		FETCH cust_cur INTO cust_rec;
		EXIT WHEN cust_cur%NOTFOUND;
			
		-- Update the Record
		UPDATE dim_customers
        SET end_date = TO_DATE(prc_start_date, 'DD/MM/YYYY')- 1,
			customer_active_flag = 'N'
		WHERE customer_key = prc_customer_id;
			
		-- Write Data into the Customer Dimension Table
		INSERT INTO dim_customers (
			customer_key,
			customer_id,
			customer_name,
			first_name,
			last_name,
			address,
			credit_limit,
			customer_status,
			customer_geography,
			start_date,
			end_date,
			customer_active_flag
		) VALUES (
			cust_seq.NEXTVAL,
			prc_customer_id,
			cust_rec.customer_name,
			cust_rec.first_name,
			cust_rec.last_name,
			cust_rec.address,
			cust_rec.credit_limit,
			cust_rec.customer_status,
			cust_rec.customer_geography,
			prc_start_date,
			'31/12/9999',
			'Y'
		);
			
		-- Display Message Indicating Successful Update
		DBMS_OUTPUT.PUT_LINE(
			'Customer with Customer ID of ' || prc_customer_id || ' updated successfully!' || CHR(10) || 
			'Start Date = ' || TO_CHAR(prc_start_date, 'DD/MM/YYYY')
		);
	END LOOP;
	
	-- Close Cursor
    CLOSE cust_cur;
	
-- Exception when no records are found
EXCEPTION
	WHEN OTHERS THEN
		-- Display Error Message
		DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/

-- Execute the Update Customer Procedure
EXEC update_customer_prc (17, '24/12/2018')

-- Examine the Customer Dimension table for the new row
SELECT * FROM dim_customers;


---- COUNTRY DIMENSION ------------------------------------------------------------------------------------------
/*
	1. Update new country and its region into the Country Dimension Table
*/
-- Insert Data into the Country Dimension
INSERT INTO dim_countries (country_key, country_id, country_name, region_name)
SELECT countries_seq.NEXTVAL,
	UPPER(ct.country_id),
    UPPER(ct.country_name),
    UPPER(r.region_name)
FROM countries ct
JOIN regions r 
	ON ct.region_id = r.region_id
WHERE country_id NOT IN (SELECT country_id FROM dim_countries);

-- Examine the Country Dimension table
SELECT * FROM dim_countries;

-- Check number of records
SELECT COUNT(*) FROM dim_countries;

-- Check the Country Dimension table structure
DESC dim_countries;


---- WAREHOUSE DIMENSION ------------------------------------------------------------------------------------------
/*
	1. Update new warehouse and its location into the Warehouse Dimension Table
*/
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
	ON l.country_id = dct.country_id
WHERE warehouse_id NOT IN (SELECT warehouse_id FROM dim_warehouses);

-- Examine the Warehouse Dimension table
SELECT * FROM dim_warehouses;

-- Check number of records
SELECT COUNT(*) FROM dim_warehouses;

-- Check the Warehouse Dimension table structure
DESC dim_warehouses;


---- EMPLOYEE DIMENSION -------------------------------------------------------------------------------------------
/*
	1. Update new employees into the Employee Dimension Table
*/
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
FROM employees emp
WHERE employee_id NOT IN (SELECT employee_id FROM dim_employees);

-- Examine the Employee Dimension table
SELECT * FROM dim_employees;

-- Check number of records
SELECT COUNT(*) FROM dim_employees;

-- Check the Employee Dimension table structure
DESC dim_employees;


/*
	2. Type 2 Slowly Changing Dimension technique: Update Employee Procedure
*/
-- Alter the session to a Date Format of 'DD/MM/YYYY'
ALTER SESSION SET NLS_DATE_FORMAT = 'DD/MM/YYYY';

-- Alter the Employee Dimension to add start_date, end_date and employee_active_flag column
ALTER TABLE dim_employees 
	ADD start_date DATE DEFAULT '01/02/2017' NOT NULL;
ALTER TABLE dim_employees 
	ADD end_date DATE DEFAULT '31/12/9999' NOT NULL;
ALTER TABLE dim_employees 
	ADD employee_active_flag CHAR(1) DEFAULT 'Y' NOT NULL;
	
-- Procedure to update the Employee Dimension
CREATE OR REPLACE PROCEDURE update_employee_prc (prc_employee_id IN NUMBER, prc_start_date IN DATE) IS
	
	-- Curser to get the Employee Details
	CURSOR emp_cur IS
		SELECT employee_key, employee_id, first_name, last_name, email, phone, hire_date, no_of_days_employed, job_title, start_date, end_date, employee_active_flag
		FROM dim_employees
		WHERE employee_id = prc_employee_id;
    
	emp_rec emp_cur%ROWTYPE;
	
	-- Variable Declaration
	is_update_allowed BOOLEAN;
	emp_count NUMBER;

BEGIN

	-- Call secure_dml function to check if update is allowed
	is_update_allowed := secure_dml;
   
	IF NOT is_update_allowed THEN
		RETURN;
	END IF;
	
	-- Check if employee exists
	SELECT COUNT(*) INTO emp_count
    FROM dim_employees
	WHERE employee_id = prc_employee_id;
    
	-- Handle Exception when no records are found
    IF emp_count = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Employee ID '||prc_employee_id||' does not exist. Please re-enter Employee ID.');
    END IF;
	
	-- Open Cursor
	OPEN emp_cur;
	
	-- Loop and Fetch the Records
	LOOP
		FETCH emp_cur INTO emp_rec;
		EXIT WHEN emp_cur%NOTFOUND;
			
		-- Update the Record
		UPDATE dim_employees
		SET end_date = TO_DATE(prc_start_date, 'DD/MM/YYYY')- 1,
			employee_active_flag = 'N'
		WHERE employee_key = prc_employee_id;
			
		-- Write Data into the Employee Dimension Table
		INSERT INTO dim_employees (
			employee_key,
			employee_id,
			first_name,
			last_name,
			email,
			phone,
			hire_date,
			job_title,
			start_date,
			end_date,
			employee_active_flag
		) VALUES (
			employ_seq.NEXTVAL,
			prc_employee_id,
			emp_rec.first_name,
			emp_rec.last_name,
			emp_rec.email,
			emp_rec.phone,
			TRUNC(SYSDATE - emp_rec.hire_date),
			emp_rec.job_title,
			prc_start_date,
			'31-DEC-9999',
			'Y'
		);
			
		-- Display Message Indicating Successful Update
		DBMS_OUTPUT.PUT_LINE(
			'Employee with Employee ID of ' || prc_employee_id || ' updated successfully!' || CHR(10) || 
			'Start Date = ' || TO_CHAR(prc_start_date, 'DD/MM/YYYY')
		);
        
	END LOOP;
	
	-- Close Cursor
    CLOSE emp_cur;
	
-- Exception when no records are found
EXCEPTION
	WHEN OTHERS THEN
		-- Display Error Message
		DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;
/

-- Execute the Update Employee Procedure
EXEC update_employee_prc (17, '24/01/2018')

-- Examine the Employee Dimension table for the new row
SELECT * FROM dim_employees;


---- SALES FACT ---------------------------------------------------------------------------------------------------

/*
	1. Update new sales order into the Sales Fact Table
*/
-- Insert Data into the Sales Fact
INSERT INTO sales_fact (date_key, product_key, customer_key, employee_key, order_id, order_status, order_date, item_quantity, standard_cost, unit_price, unit_profit, order_total_price, gross_profit) 
SELECT dd.date_key,
		dp.product_key, 
		dc.customer_key, 
		de.employee_key,	-- NVL(de.employee_key, 9999999) as employee_key,
		o.order_id,
		o.status, 
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
	ON o.salesman_id = de.employee_id
WHERE o.order_date > (SELECT MAX(order_date) FROM sales_fact);

-- Examine the Sales Fact table
SELECT * FROM sales_fact;
	
-- Update the dim_employees with dummy employee records for orders in orders table with NULL values. 
UPDATE sales_fact
SET employee_key = 9999999
WHERE employee_key IS NULL;


---- INVENTORY FACT -----------------------------------------------------------------------------------------------
/*
	1. Update new inventory products into the Inventory Fact Table
*/
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
	ON w.warehouse_id = dw.warehouse_id
WHERE NOT EXISTS (SELECT 1
                  FROM inventories_fact
                  WHERE inventories_fact.product_key = dp.product_key
                  AND inventories_fact.warehouse_key = dw.warehouse_key);
				  
-- Examine the Inventory Fact table
SELECT * FROM inventories_fact;

-- Check number of records, should be 1,112
SELECT COUNT(*) FROM inventories_fact;

-- Check the Inventory Fact table structure
DESC inventories_fact;