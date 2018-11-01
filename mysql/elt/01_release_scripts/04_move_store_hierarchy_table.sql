/*
  Script:
    02_move_store_hierarchy_table.sql
  Description:
    Move store_hierarchy table from semistatic_catalog to static_catalog schema.
*/
SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
SET @@SESSION.SQL_MODE = 'TRADITIONAL';

SET @OLD_SCHEMA_NAME = 'semistatic_catalog';
SET @NEW_SCHEMA_NAME = 'static_catalog';
SET @TABLE_NAME      = 'store_hierarchy';

UPDATE elt.src_tables
   SET src_schema_name = @NEW_SCHEMA_NAME 
 WHERE src_schema_name = @OLD_SCHEMA_NAME
   AND src_table_name  = @TABLE_NAME
;   
COMMIT;

SELECT CONCAT("====> The record '", @TABLE_NAME, "' has been updated in 'elt.src_tables' table") AS "Info:" FROM dual;

SET @@SESSION.SQL_MODE = @old_sql_mode;
