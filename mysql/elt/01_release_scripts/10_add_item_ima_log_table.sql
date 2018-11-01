-- ======================================================== 
--                  Add Table
-- --------------------------------------------------------
-- Script: add_item_ima_log_table.sql
-- ======================================================== 
 
SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
SET @@SESSION.SQL_MODE = '';

SET @HOST_ALIAS        = 'db2';
SET @SRC_SCHEMA_NAME   = 'catalog';
SET @SRC_TABLE_NAME    = 'item_ima_log';
SET @SRC_TABLE_ALIAS   = 'iimal';
SET @DST_DB_ENGINE     = 'InnoDB';
SET @DEBUG_MODE        = FALSE;

-- Imporatnt Notes: 
-- 1. New table should be created in DB3
-- 2. ALL table structure changes (DDL) should be applied before ading the table to ELT process

-- ====================================
-- 1. Create record in src_tables
-- ====================================
CALL elt.populate_src_tables (@err_num, @HOST_ALIAS, @DST_DB_ENGINE, @SRC_SCHEMA_NAME, @SRC_TABLE_NAME, NULL, NULL, NULL, ';', @DEBUG_MODE);

SET @sql_stmt = IF(@err_num <> 0,
                   CONCAT('SELECT "====> Create record about ''', @SRC_TABLE_NAME, ''' table: Error = ', @err_num, '" AS "Error:" FROM dual'),
                   CONCAT('SELECT "====> Created record about ''', @SRC_TABLE_NAME, ''' table: OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
COMMIT;

-- ====================================
-- 2. "Validate" table
-- ====================================
SET @is_table_exists = 0;
SELECT 1
  INTO @is_table_exists
  FROM information_schema.tables
 WHERE table_schema = @SRC_SCHEMA_NAME
   AND table_name   = @SRC_TABLE_NAME;  

SET @sql_stmt = IF(@is_table_exists = 1,
                   CONCAT('UPDATE elt.src_tables SET src_table_valid_status = 1 WHERE host_alias = ''', @HOST_ALIAS, ''' AND src_schema_name = ''', @SRC_SCHEMA_NAME, ''' AND src_table_name = ''', @SRC_TABLE_NAME, ''''),
                   CONCAT('SELECT "====> Table ''', @SRC_TABLE_NAME, ''' has not been created" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Message
SET @sql_stmt = IF(@is_table_exists = 1,
                   CONCAT('SELECT "====> Table ''', @SRC_TABLE_NAME, ''' has been validated" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Table ''', @SRC_TABLE_NAME, ''' could not be validated" AS "Error:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 3. Change table_alias in src_tables
-- ====================================
SET @sql_stmt = IF(@is_table_exists = 1,
                    CONCAT('UPDATE elt.src_tables SET src_table_alias = ''',  @SRC_TABLE_ALIAS, ''' WHERE host_alias = ''', @HOST_ALIAS, ''' AND src_schema_name = ''', @SRC_SCHEMA_NAME, ''' AND src_table_name = ''', @SRC_TABLE_NAME, ''''),
                    CONCAT('SELECT "====> Table ''', @SRC_SCHEMA_NAME ,'.', @SRC_TABLE_NAME, ''' already exists " AS "Info:" FROM dual')
                   ); 
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query;
-- Message
SET @sql_stmt = IF(@is_table_exists = 1,
                   CONCAT('SELECT "====> The alias of the ''', @SRC_TABLE_NAME, ''' table has been updated" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Nothing to update..." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 4. If data was already downloaded by mysqldump
--    override_dtm = NULL
-- ====================================
SET @sql_stmt = IF(@is_table_exists = 1,
                    CONCAT('UPDATE elt.src_tables SET override_dtm = NULL WHERE host_alias = ''', @HOST_ALIAS, ''' AND src_schema_name = ''', @SRC_SCHEMA_NAME, ''' AND src_table_name = ''', @SRC_TABLE_NAME, ''''),
                    CONCAT('SELECT "====> Table ''', @SRC_SCHEMA_NAME ,'.', @SRC_TABLE_NAME, ''' already exists " AS "Info:" FROM dual')
                   ); 
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query;
-- Message
SET @sql_stmt = IF(@is_table_exists = 1,
                   CONCAT('SELECT "====> The override_dtm value for ''', @SRC_TABLE_NAME, ''' table has been set to NULL" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Nothing to update..." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

COMMIT;

SET @@SESSION.SQL_MODE = @old_sql_mode;
