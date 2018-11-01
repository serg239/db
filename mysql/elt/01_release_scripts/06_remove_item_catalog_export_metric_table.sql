/*
  Script:
    03_remove_item_catalog_export_metric_table.sql
  Description:
    Remove catalog.item_catalog_export_metric table from ELT process:
    we do not populate this table from DB2 every 2 hours anymore,
    the table updated from application.
*/
SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
SET @@SESSION.SQL_MODE = 'TRADITIONAL';

SET @SCHEMA_NAME = 'catalog';
SET @TABLE_NAME  = 'item_catalog_export_metric';

--
-- Table updated from application now
--
UPDATE elt.src_tables
   SET src_table_load_status  = 0,         -- do not download anymore
       src_table_valid_status = 0
 WHERE src_schema_name = @SCHEMA_NAME
   AND src_table_name  = @TABLE_NAME
;   
COMMIT;

SELECT "====> The record 'item_catalog_export_metric' has been updated in 'elt.src_tables' table" AS "Info:" FROM dual;

SET @@SESSION.SQL_MODE = @old_sql_mode;


