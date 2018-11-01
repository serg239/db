/*
  Version:
    2011.12.11.01
  Script:
    00_drop_elt_fed_tables.sql  
  Description:
    Drop all FED tables in "elt" schema.
  Usage:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\00_drop_elt_fed_tables.sql
*/

SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
SET @@SESSION.SQL_MODE = '';

SET @ELT_SCHEMA_NAME   = 'elt';

SET @DB1_IS_COLUMNS = 'db1_information_schema_columns';
SET @DB2_IS_COLUMNS = 'db2_information_schema_columns';
SET @DB1_IS_INDEXES = 'db1_information_schema_indexes';
SET @DB2_IS_INDEXES = 'db2_information_schema_indexes';

-- ====================================
-- DROP DB1 FED COLUMNS table
-- ====================================
SET @v_table_exists = FALSE;
SELECT TRUE 
  INTO @v_table_exists
  FROM information_schema.tables 
 WHERE table_schema = @ELT_SCHEMA_NAME
   AND table_name   = @DB1_IS_COLUMNS;

SET @sql_stmt = IF(@v_table_exists = TRUE,
                   CONCAT('DROP TABLE ', @ELT_SCHEMA_NAME, '.', @DB1_IS_COLUMNS),
                   CONCAT('SELECT "====> Table ''', @ELT_SCHEMA_NAME, '.', @DB1_IS_COLUMNS, ''' does not  exist" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Show Message
SET @sql_stmt = IF(@v_table_exists = TRUE,
                   CONCAT('SELECT "====> Table ''', @ELT_SCHEMA_NAME, '.', @DB1_IS_COLUMNS, ''' has been dropped" AS "Info:" FROM dual'),
                   'SELECT "====> Nothing to drop..." AS "Info:" FROM dual'
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- DROP DB1 FED INDEXES table
-- ====================================
SET @v_table_exists = FALSE;
SELECT TRUE 
  INTO @v_table_exists
  FROM information_schema.tables 
 WHERE table_schema = @ELT_SCHEMA_NAME
   AND table_name   = @DB1_IS_INDEXES;

SET @sql_stmt = IF(@v_table_exists = TRUE,
                   CONCAT('DROP TABLE ', @ELT_SCHEMA_NAME, '.', @DB1_IS_INDEXES),
                   CONCAT('SELECT "====> Table ''', @ELT_SCHEMA_NAME, '.', @DB1_IS_INDEXES, ''' does not  exist" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Show Message
SET @sql_stmt = IF(@v_table_exists = TRUE,
                   CONCAT('SELECT "====> Table ''', @ELT_SCHEMA_NAME, '.', @DB1_IS_INDEXES, ''' has been dropped" AS "Info:" FROM dual'),
                   'SELECT "====> Nothing to drop..." AS "Info:" FROM dual'
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- DROP DB2 FED COLUMNS table
-- ====================================
SET @v_table_exists = FALSE;
SELECT TRUE 
  INTO @v_table_exists
  FROM information_schema.tables 
 WHERE table_schema = @ELT_SCHEMA_NAME
   AND table_name   = @DB2_IS_COLUMNS;

SET @sql_stmt = IF(@v_table_exists = TRUE,
                   CONCAT('DROP TABLE ', @ELT_SCHEMA_NAME, '.', @DB2_IS_COLUMNS),
                   CONCAT('SELECT "====> Table ''', @ELT_SCHEMA_NAME, '.', @DB2_IS_COLUMNS, ''' does not  exist" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Show Message
SET @sql_stmt = IF(@v_table_exists = TRUE,
                   CONCAT('SELECT "====> Table ''', @ELT_SCHEMA_NAME, '.', @DB2_IS_COLUMNS, ''' has been dropped" AS "Info:" FROM dual'),
                   'SELECT "====> Nothing to drop..." AS "Info:" FROM dual'
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- DROP DB2 FED INDEXES table
-- ====================================
SET @v_table_exists = FALSE;
SELECT TRUE 
  INTO @v_table_exists
  FROM information_schema.tables 
 WHERE table_schema = @ELT_SCHEMA_NAME
   AND table_name   = @DB2_IS_INDEXES;

SET @sql_stmt = IF(@v_table_exists = TRUE,
                   CONCAT('DROP TABLE ', @ELT_SCHEMA_NAME, '.', @DB2_IS_INDEXES),
                   CONCAT('SELECT "====> Table ''', @ELT_SCHEMA_NAME, '.', @DB2_IS_INDEXES, ''' does not  exist" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Show Message
SET @sql_stmt = IF(@v_table_exists = TRUE,
                   CONCAT('SELECT "====> Table ''', @ELT_SCHEMA_NAME, '.', @DB2_IS_INDEXES, ''' has been dropped" AS "Info:" FROM dual'),
                   'SELECT "====> Nothing to drop..." AS "Info:" FROM dual'
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

SET @v_table_exists = NULL;
SET @sql_stmt       = NULL;

COMMIT;

SET @@SESSION.SQL_MODE = @old_sql_mode;
