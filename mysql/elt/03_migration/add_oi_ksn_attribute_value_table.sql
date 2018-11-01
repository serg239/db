-- ======================================================== 
--                  Add Table
-- --------------------------------------------------------
-- Script: add_oi_ksn_attribute_value_table.sql
-- ======================================================== 
 
SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
SET @@SESSION.SQL_MODE = '';

SET @DELTA_SCHEMA_TYPE = 'DELTA';            -- Upper Case
SET @LINK_SCHEMA_TYPE  = 'LINK';             -- Upper Case

SET @ELT_SCHEMA_NAME  = 'elt';
SET @DELTA_SCHEMA_NAME = 'db_delta';       -- Lower Case 
SET @LINK_SCHEMA_NAME  = 'db_link';        -- Lower Case 

SET @HOST_ALIAS        = 'db2';
SET @SHARD_NUMBER      = '01';                -- CHAR(2)
SET @SRC_SCHEMA_NAME   = 'load_catalog';
SET @SRC_TABLE_NAME    = 'oi_ksn_attribute_value';
SET @SRC_TABLE_ALIAS   = 'okav';
SET @DST_DB_ENGINE     = 'InnoDB';
SET @DEBUG_MODE        = FALSE;

SELECT CONCAT('====> Table ''', @SRC_TABLE_NAME, ''': Started at ', CURRENT_TIMESTAMP()) AS "Info:" FROM dual;

--
-- Imporatnt Notes: 
--
-- 1. ALL Constraints should be dropped
-- 2. New table should be created in DB schema of STAGE area
-- 3. ALL table structure changes (DDL) should be applied before ading the table to ELT process
-- 4. DELTA schema should be dropped
-- 5. LINK schema should be dropped

-- ====================================
-- 1. Drop constraints - just in case
-- ====================================
-- CALL elt.check_drop_constraints_stmt (@err_num, FALSE); -- not debug, execute DROP FKs
-- SET @sql_stmt = IF(@err_num <> 0,
--                    CONCAT('SELECT "====> DROP constraints in all tables : Error #', @err_num, 'AS "Error:" FROM dual'),
--                    CONCAT('SELECT "====> DROP constraints in all tables: OK" AS "Info:" FROM dual')
--                   );
-- PREPARE query FROM @sql_stmt;
-- EXECUTE query;
-- DEALLOCATE PREPARE query; 

-- ====================================
-- 2. Delete all child records from downloads
-- ====================================
DELETE FROM elt.control_downloads
 WHERE host_alias      = @HOST_ALIAS
   AND src_schema_name = @SRC_SCHEMA_NAME
   AND src_table_name  = @SRC_TABLE_NAME
;
COMMIT;

-- ====================================
-- 3. Delete record from elt.src_tables 
-- ====================================
DELETE FROM elt.src_tables
 WHERE host_alias      = @HOST_ALIAS
   AND src_schema_name = @SRC_SCHEMA_NAME
   AND src_table_name  = @SRC_TABLE_NAME
;
COMMIT;

SELECT CONCAT('====> Record about ''', @SRC_TABLE_NAME, ''' has been deleted') AS "Info:" FROM dual;

-- ====================================
-- 4. Truncate DB table in STAGE area
-- ====================================
SET @sql_stmt = CONCAT('TRUNCATE TABLE ', @SRC_SCHEMA_NAME, '.', @SRC_TABLE_NAME);
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

SELECT CONCAT('====> Table ''', @SRC_TABLE_NAME, ''' has been truncated') AS "Info:" FROM dual;

-- ====================================
-- 5. Add info about SRC table to src_tables 
--    Note: override_dtm = "2000-01-01 00:00:00"
-- ====================================
-- Add records to src_tables (for all shards)
CALL elt.populate_src_tables (@err_num, @HOST_ALIAS, @DST_DB_ENGINE, @SRC_SCHEMA_NAME, @SRC_TABLE_NAME, NULL, NULL, NULL, ';', @DEBUG_MODE);
SET @sql_stmt = IF(@err_num <> 0,
                   CONCAT('SELECT "====> Create record about ''', @SRC_TABLE_NAME, ''' table : Error #', @err_num, 'AS "Error:" FROM dual'),
                   CONCAT('SELECT "====> Created record about ''', @SRC_TABLE_NAME, ''' table : OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 6. "Validate" table
-- ====================================
SET @is_table_exists = 0;
SELECT 1
  INTO @is_table_exists
  FROM information_schema.tables
 WHERE table_schema = @SRC_SCHEMA_NAME
   AND table_name = @SRC_TABLE_NAME;  
SET @sql_stmt = IF(@is_table_exists = 1,
                   CONCAT('UPDATE elt.src_tables SET src_table_valid_status = 1 WHERE host_alias = ''', @HOST_ALIAS, ''' AND src_schema_name = ''', @SRC_SCHEMA_NAME, ''' AND src_table_name = ''', @SRC_TABLE_NAME, ''''),
                   CONCAT('SELECT "====> Table ''', @SRC_TABLE_NAME, ''' has not been created : ERROR" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- Message
SET @sql_stmt = IF(@is_table_exists = 1,
                   CONCAT('SELECT "====> Validate ''', @SRC_TABLE_NAME, ''' table : OK" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Validate ''', @SRC_TABLE_NAME, ''' table : Error #-2 AS "Error:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- CALL elt.validate_src_tables (@err_num, @HOST_ALIAS, @SRC_SCHEMA_NAME, @SRC_TABLE_NAME, @DEBUG_MODE);
-- SET @sql_stmt = IF(@err_num <> 0,
--                    CONCAT('SELECT "====> Validate ''', @SRC_TABLE_NAME, ''' table : Error #', @err_num, 'AS "Error:" FROM dual'),
--                    CONCAT('SELECT "====> Validate ''', @SRC_TABLE_NAME, ''' table : OK" AS "Info:" FROM dual')
--                   );
-- PREPARE query FROM @sql_stmt;
-- EXECUTE query;
-- DEALLOCATE PREPARE query; 

-- ====================================
-- 7. Change table_alias and reset override_dtm to NULL in src_tables
-- ====================================
UPDATE elt.src_tables 
   SET src_table_alias = @SRC_TABLE_ALIAS,
       override_dtm    = NULL 
 WHERE host_alias      = @HOST_ALIAS
   AND src_schema_name = @SRC_SCHEMA_NAME
   AND src_table_name  = @SRC_TABLE_NAME; 

COMMIT;

SELECT CONCAT('====> Table ''', @SRC_TABLE_NAME, ''': Finished at ', CURRENT_TIMESTAMP()) AS "Info:" FROM dual;

SET @@SESSION.SQL_MODE = @old_sql_mode;
