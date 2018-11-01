MySQL Database. Examples.
=========================

* release/release.sh - confugurable shell script to **deploy or migrate** MySQL database:
  * Operational Procedures
  * Grants
  * DDL
  * Triggers
  * Migration
  * Post-migration
  * Code (APIs)
* mysql/compare - configurable shell scripts to **compare** Source and Target Databases
* mysql/account - example of the **"account" schema** creation
  * Naming convention
  * Formatted SQL statements
  * PK and FK constraints
  * Default values
  * Log tables
  * Triggers
  * Procedures
* mysql/tools - examples of metadata management
  * check and alter table
  * check if change applied
  * clean DDL
  * create table partitions
  * recreate FEDERATED tables
* mysql/elt - Extract-Load-Transform (**ELT**) schemas
  * Release scripts
  * Procedures
  * Migration
  * Dynamic SQL
  * FEDERATED tables
  * Sharding
  * Logs
  * SQL and bat scripts to manage schemas 
* mysql/reports - examples of complex **report** statements
  * SQL scripts
* mysql/store - examples from the **"store" schema**
  * Sharding
  * Shell scripts to run reports
  * SQL scripts
* mysql/proc - creators, getters, and setters for "account" schema
  * check if account exists
  * create/delete/update/get account
  * get shards by using account
