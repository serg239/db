-- ======================================================== 
--                  Add Table
-- --------------------------------------------------------
-- Script: add_external_account_table.sql
-- ======================================================== 
 
SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
SET @@SESSION.SQL_MODE = '';

SET @DELTA_SCHEMA_TYPE = 'DELTA';          -- Upper Case
SET @LINK_SCHEMA_TYPE  = 'LINK';           -- Upper Case

SET @ELT_SCHEMA_NAME   = 'elt';
SET @DELTA_SCHEMA_NAME = 'db_delta';       -- Lower Case 
SET @LINK_SCHEMA_NAME  = 'db_link';        -- Lower Case 

SET @HOST_ALIAS        = 'db2';
SET @SHARD_NUMBER      = '01';                -- CHAR(2)
SET @SRC_SCHEMA_NAME   = 'external_content';
SET @SRC_TABLE_NAME    = 'external_account';
SET @SRC_TABLE_ALIAS   = 'eacc';
SET @DST_DB_ENGINE     = 'InnoDB';
SET @DEBUG_MODE        = FALSE;

SELECT CONCAT('====> Table ''', @src_table_name, ''': Started at ', CURRENT_TIMESTAMP()) AS "Info:" FROM dual;

--
-- Get last download num
--
SELECT MAX(download_num) INTO @last_download_num 
  FROM elt.control_downloads;

-- ====================================
-- Drop table in db schema
-- ====================================
-- Check if table exists
SET @v_table_exists = 0;
SELECT 1
  INTO @v_table_exists
  FROM information_schema.tables
 WHERE table_schema = @SRC_SCHEMA_NAME
   AND table_name   = @SRC_TABLE_NAME;
-- Drop table in db schema
SET @sql_stmt = IF(@v_table_exists = 1,
                   CONCAT('DROP TABLE ', @SRC_SCHEMA_NAME, '.', @SRC_TABLE_NAME),
                   CONCAT('SELECT "====> Table ''', @SRC_SCHEMA_NAME, '.', @SRC_TABLE_NAME, ''' does not exist: OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Show Message
SET @sql_stmt = IF(@v_table_exists = 1,
                   CONCAT('SELECT "====> Table ''', @SRC_SCHEMA_NAME, '.', @SRC_TABLE_NAME, ''' has been dropped" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Nothing to drop ..." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- Drop table in DELTA schema
-- ====================================
-- Check if table exists
SET @v_table_exists = 0;
SELECT 1
  INTO @v_table_exists
  FROM information_schema.tables
 WHERE table_schema = @DELTA_SCHEMA_NAME
   AND table_name   = @SRC_TABLE_NAME;
-- Drop table in db schema
SET @sql_stmt = IF(@v_table_exists = 1,
                   CONCAT('DROP TABLE ', @DELTA_SCHEMA_NAME, '.', @SRC_TABLE_NAME),
                   CONCAT('SELECT "====> Table ''', @DELTA_SCHEMA_NAME, '.', @SRC_TABLE_NAME, ''' does not exist: OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Show Message
SET @sql_stmt = IF(@v_table_exists = 1,
                   CONCAT('SELECT "====> Table ''', @DELTA_SCHEMA_NAME, '.', @SRC_TABLE_NAME, ''' has been dropped" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Nothing to drop ..." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- Delete record FROM elt.control_downloads, last download
-- ====================================
DELETE FROM elt.control_downloads 
 WHERE host_alias      = @HOST_ALIAS
   AND src_schema_name = @SRC_SCHEMA_NAME
   AND src_table_name  = @SRC_TABLE_NAME
   AND download_num    = @last_download_num
;
-- ====================================
-- Delete record FROM elt.src_tables 
-- ====================================
DELETE FROM elt.src_tables 
 WHERE host_alias      = @HOST_ALIAS
   AND src_schema_name = @SRC_SCHEMA_NAME
   AND src_table_name  = @SRC_TABLE_NAME
;
COMMIT;

-- ==================================
-- Check/Create DELTA schema
-- ==================================
SET @v_schema_exists = 0;
SELECT 1
  INTO @v_schema_exists
  FROM information_schema.schemata
 WHERE schema_name = @DELTA_SCHEMA_NAME;
-- Drop table in db schema
SET @sql_stmt = IF(@v_schema_exists = 0,
                   CONCAT('CREATE SCHEMA ', @DELTA_SCHEMA_NAME, ' DEFAULT CHARACTER SET utf8 COLLATE utf8_bin'),
                   CONCAT('SELECT "====> Schema ''', @DELTA_SCHEMA_NAME, ''' already exists: OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Show Message
SET @sql_stmt = IF(@v_schema_exists = 0,
                   CONCAT('SELECT "====> Schema ''', @DELTA_SCHEMA_NAME, ''' has been created" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Nothing to create ..." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ==================================
-- Drop/Create LINK schema and shard tables
-- ==================================
CALL elt.create_elt_schema (@err_num, @LINK_SCHEMA_TYPE, @DEBUG_MODE);   -- db_link  (shard tables)
SET @sql_stmt = IF(@err_num <> 0,
                   CONCAT('SELECT "====> Create ''', @LINK_SCHEMA_NAME, ''' schema: Error #', @err_num, 'AS "Error:" FROM dual'),
                   CONCAT('SELECT "====> Create ''', @LINK_SCHEMA_NAME, ''' schema: OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- Add info about SRC table to src_tables: elt.populate_src_tables(), elt.validate_src_tables()
-- Create table in DELTA schema
-- ====================================
CALL elt.add_elt_table (@err_num, @DELTA_SCHEMA_TYPE, @HOST_ALIAS, @SRC_SCHEMA_NAME, @SRC_TABLE_NAME, @DST_DB_ENGINE, @DEBUG_MODE);
SET @sql_stmt = IF(@err_num <> 0,
                   CONCAT('SELECT "====> Create ''', @SRC_TABLE_NAME, ''' table in DELTA schema: Error #', @err_num, 'AS "Error:" FROM dual'),
                   CONCAT('SELECT "====> Create ''', @SRC_TABLE_NAME, ''' table in DELTA schema: OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- Change table_alias and reset override_dtm to NULL in src_tables
-- ====================================
UPDATE elt.src_tables 
   SET src_table_alias = @SRC_TABLE_ALIAS,
       override_dtm = NULL 
 WHERE host_alias      = @HOST_ALIAS
   AND src_schema_name = @SRC_SCHEMA_NAME
   AND src_table_name  = @SRC_TABLE_NAME; 

COMMIT;

-- ====================================
-- Create table in db schema
-- ====================================
CALL elt.add_elt_table (@err_num, NULL, @HOST_ALIAS, @SRC_SCHEMA_NAME, @SRC_TABLE_NAME, @DST_DB_ENGINE, @DEBUG_MODE);
SET @sql_stmt = IF(@err_num <> 0,
                   CONCAT('SELECT "====> Create ''', @SRC_TABLE_NAME, ''' table in db schema: Error #', @err_num, 'AS "Error:" FROM dual'),
                   CONCAT('SELECT "====> Create ''', @SRC_TABLE_NAME, ''' table in db schema: OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- Prepare record for data migration
-- ====================================
INSERT INTO elt.control_downloads (download_num, src_table_id, host_alias, shard_number, src_schema_name, src_table_name,
                                   download_status, filter_status, append_status, transform_status, 
                                   control_type, 
                                   control_start_dtm, 
                                   control_end_dtm, 
                                   where_clause, 
                                   order_by_clause, 
                                   created_by, 
                                   created_at) 
SELECT @last_download_num, st.src_table_id, @HOST_ALIAS, @SHARD_NUMBER, @SRC_SCHEMA_NAME, @SRC_TABLE_NAME,
       0, 0, 0, 0, 
       @DELTA_SCHEMA_TYPE,
       '2000-01-01 00:00:00',           -- control_start_dtm
       FROM_UNIXTIME(ROUND(UNIX_TIMESTAMP(CURRENT_TIMESTAMP)/(60*30))*(60*30)),  -- control_end_dtm
       st.where_clause,                 -- where_clause 
       st.order_by_clause,              -- order_by_clause 
       SUBSTRING_INDEX(USER(), '@', 1), -- created_by
       CURRENT_TIMESTAMP()              -- created_at
  FROM elt.src_tables  st
    INNER JOIN elt.shard_profiles  spf
      ON st.shard_profile_id = st.shard_profile_id
        AND spf.status = 1
 WHERE st.host_alias      = @HOST_ALIAS
   AND st.src_schema_name = @SRC_SCHEMA_NAME
   AND st.src_table_name  = @SRC_TABLE_NAME
   AND st.src_table_load_status  = 1   -- active
   AND st.src_table_valid_status = 1   -- valid
   AND st.src_table_name <> spf.shard_table_name  -- shard_account_list table should be created in LINK schema only
 ORDER BY st.src_table_id;

COMMIT;

SELECT "====> Added record to 'control_downloads' table" AS "Info:" FROM dual;

--
-- Load data into DELTA table
--
CALL elt.load_elt_data(@err_num, @DELTA_SCHEMA_TYPE, @DEBUG_MODE);
-- 
SET @sql_stmt = IF(@err_num <> 0,
                   CONCAT('SELECT "====> Load Data: Error #', @err_num, 'AS "Error:" FROM dual'),
                   CONCAT('SELECT "====> Load Data: OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

--
-- Append DELTA to db table
-- and Truncate table in DELTA schema
--
SET @REMOVE_DUP_FLAG = FALSE;
SET @VALIDATE_FLAG   = FALSE;
--
CALL elt.append_delta (@err_num, @REMOVE_DUP_FLAG, @VALIDATE_FLAG, @DEBUG_MODE);
--
SET @sql_stmt = IF(@err_num <> 0,
                   CONCAT('SELECT "====> Append DELTA: Error #', @err_num, 'AS "Error:" FROM dual'),
                   CONCAT('SELECT "====> Append DELTA: OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- Drop LINK schema
DROP SCHEMA IF EXISTS db_link;

--
-- Drop temporary tables in ELT schema (in case of broken of the previous processes)
--
CALL elt.drop_tmp_tables (@err_num, @ELT_SCHEMA_NAME);
--
SET @sql_stmt = IF(@err_num <> 0,
                   CONCAT('SELECT "====> Drop temporary tables: Error #', @err_num, 'AS "Error:" FROM dual'),
                   CONCAT('SELECT "====> Drop temporary tables: OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

SELECT CONCAT('====> Table ''', @SRC_TABLE_NAME, ''': Finished at ', CURRENT_TIMESTAMP()) AS "Info:" FROM dual;

SET @@SESSION.SQL_MODE = @old_sql_mode;

-- ======================================================== 

