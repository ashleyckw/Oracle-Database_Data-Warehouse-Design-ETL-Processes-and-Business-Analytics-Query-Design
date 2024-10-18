# Oracle-Database_Data-Warehouse-Design-ETL-Processes-and-Business-Analytics-Query-Design
This project implements an end-to-end Data Warehouse using Oracle and PL/SQL. It involves designing a star schema, creating dimension and fact tables, optimizing ETL (Extract, Transform, Load) processes, and developing business analytics dashboards for comprehensive insights into sales, inventory, and employee performance.

## Key Features
This proStar Schema Design: Dimension and fact tables for sales, inventory, employee performance, and more.
ETL Optimization: PL/SQL scripts for efficient data transformation and seamless integration.
Business Intelligence: Advanced analytics reports and dashboards providing actionable insights on key metrics.
Query Optimization: Enhanced query performance through strategic indexing and optimization techniques.

## Technologies Used
* Oracle Database
* PL/SQL
* ETL Tools
* Star/Snowflake Schema Design
* SQL Query Optimization
* Business Analytics

## Usage
The repository includes .txt files with PL/SQL scripts for creating and managing dimension and fact tables, as well as ETL processes.
To execute these files, connect to your Oracle Database instance and run the scripts in the correct order:
1. Create original database and load data into the original database.
2. Create fact and dimention tables.
3. Execute ETL processes for data loading.
4. Generate analytics reports from the data warehouse.

## Files
* ```cr_schema.txt```: Contains SQL scripts for creating the Original Database (logical design).
* ```cr_data.txt```: Loads data into the Original Database.
* ```drop.txt```: Drops tables from the Original Database.
* ```initial_etl.sql```: Script for the initial creation of tables during the ETL processes (physical design).
* ```initial_load_data.sql```: Script for the initial data load during the ETL processes.
* ```subsequent_etl.sql```: Script for the subsequent creation of tables during the ETL processes.
* ```subsequent_load_data.sql```: Script for the subsequent data load during the ETL processes.
* ```3.1.1.txt``` to ```3.4.3.txt```: SQL queries for generatin gbusiness analytics reports.

## Project Impact
This project delivers a fully functional data warehouse with real-time data insights, optimized for business intelligence. The system provides crucial insights into sales trends, inventory levels, and employee performance using advanced analytics dashboards.
