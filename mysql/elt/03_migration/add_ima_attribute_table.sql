-- ======================================================== 
--                  Add Table
-- --------------------------------------------------------
-- Script: add_ima_attribute_table.sql
-- ======================================================== 
 
SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
SET @@SESSION.SQL_MODE = '';

SET @DELTA_SCHEMA_TYPE = 'DELTA';            -- Upper Case
SET @LINK_SCHEMA_TYPE  = 'LINK';             -- Upper Case

SET @ELT_SCHEMA_NAME   = 'elt';
SET @DELTA_SCHEMA_NAME = 'db_delta';       -- Lower Case 
SET @LINK_SCHEMA_NAME  = 'db_link';        -- Lower Case 

SET @HOST_ALIAS        = 'db2';
SET @SHARD_NUMBER      = '01';                -- CHAR(2)
SET @SRC_SCHEMA_NAME   = 'static_content';
SET @SRC_TABLE_NAME    = 'ima_attribute';
SET @SRC_TABLE_ALIAS   = 'imat';
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
SET @is_table_exists = 0;
SELECT 1
  INTO @is_table_exists
  FROM information_schema.tables
 WHERE table_schema = @SRC_SCHEMA_NAME
   AND table_name   = @SRC_TABLE_NAME;  
SET @sql_stmt = IF(@is_table_exists = 1,
                   CONCAT('TRUNCATE TABLE ', @SRC_SCHEMA_NAME, '.', @SRC_TABLE_NAME),
                   CONCAT('SELECT "====> Table ''', @SRC_TABLE_NAME, ''' has not been created : OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Message
SET @sql_stmt = IF(@is_table_exists = 1,
                   CONCAT('SELECT "====> Table ''', @SRC_TABLE_NAME, ''' has been truncated : ERROR" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Nothing to truncate..." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 5. Add info about SRC table to src_tables 
--    Note: override_dtm = "2000-01-01 00:00:00"
-- ====================================
-- Add records to src_tables (for all shards)
--CALL elt.populate_src_tables (@err_num, @HOST_ALIAS, @DST_DB_ENGINE, @SRC_SCHEMA_NAME, @SRC_TABLE_NAME, NULL, NULL, NULL, ';', @DEBUG_MODE);
INSERT INTO elt.src_tables 
(
  shard_profile_id, 
  host_alias, 
  shard_number, 
  src_schema_name, 
  src_table_name, 
  src_table_alias, 
  src_table_type, 
  src_table_load_status, 
  src_table_valid_status, 
  override_dtm, 
  dtm_column_name, 
  sharding_column_name, 
  proc_pk_column_name,
  proc_block_size,
  delta_schema_name,
  dst_schema_name,
  dst_table_name,
  db_engine_type,
  created_by,
  created_at
)
VALUES 
(
  (SELECT spf.shard_profile_id 
     FROM elt.shard_profiles spf
    WHERE spf.host_alias   = @HOST_ALIAS
      AND spf.shard_number = @SHARD_NUMBER
      AND spf.status       = 1
  )                     AS shard_profile_id,
  @HOST_ALIAS           AS host_alias,
  @SHARD_NUMBER         AS shard_number,
  @SRC_SCHEMA_NAME      AS src_schema_name,
  @SRC_TABLE_NAME       AS src_table_name,
  @SRC_TABLE_ALIAS      AS src_table_alias,
  CASE WHEN POSITION("_log" IN isc.table_name) > 0 THEN "LOG"
                                                   ELSE "MASTER"
  END                   AS src_table_type,
  1                     AS src_table_load_status,
  1                     AS src_table_valid_status,
  CAST("2000-01-01 00:00:00" AS DATETIME)  AS override_dtm, 
  q4.dtm_column_name                       AS dtm_column_name,
  q3.column_name                           AS sharding_column_name,
  IFNULL(q1.pk_column_name, 
  q2.first_column_name)             AS proc_pk_column_name, 
          IF (q4.dtm_column_name IS NULL,
              -1,                                                                  -- NO DTM - entire table (STAGE or DELTA)  
              IF(q1.pk_column_name IS NULL,
                 0,                                                                -- NO PK - no blocks (STAGE)
                 IF ((''', v_host_alias, ''' = ''', DB1_HOST_ALIAS, ''') AND (isc.table_name NOT LIKE "%_log"), 
                     0,
                     IF (
                         (''', v_host_alias, ''' = ''', DB2_HOST_ALIAS, ''') AND (isc.table_name NOT LIKE "%_log"), 
                         100000,
                         IF ((isc.table_name LIKE "%_log"),
                             1000000, 
                             0
                            )
                        )
                    )
                )  
            )           AS proc_block_size,
  'db_delta'          AS delta_schema_name,
  'db_stage'          AS dst_schema_name,
  @SRC_SCHEMA_NAME      AS dst_table_name,
  @DST_DB_ENGINE        AS db_engine_type,
  SUBSTRING_INDEX(CURRENT_USER, "@", 1)  AS created_by,
  CURRENT_TIMESTAMP()                    AS created_at

FROM information_schema.columns  isc
  LEFT OUTER JOIN
    (SELECT isc1.table_schema,
            isc1.table_name,
            IF((isc1.table_name LIKE "%_log"),
               REPLACE(isc1.column_name, "_log", ""),
               isc1.column_name
              )  AS pk_column_name
       FROM elt.db1_information_schema_columns  isc1
      WHERE isc1.column_key = "PRI"
    ) q1
    ON isc.table_schema  = q1.table_schema
      AND isc.table_name = q1.table_name');
)
;

+------------------+------------+--------------+-----------------+----------------+-----------------+----------------+-----------------------+------------------------+---------------------+-----------------+----------------------+---------------------+-----------------+-------------------+-----------------+----------------+----------------+------------+---------------------+
| shard_profile_id | host_alias | shard_number | src_schema_name | src_table_name | src_table_alias | src_table_type | src_table_load_status | src_table_valid_status | override_dtm        | dtm_column_name | sharding_column_name | proc_pk_column_name | proc_block_size | delta_schema_name | dst_schema_name | dst_table_name | db_engine_type | created_by | created_at          |
+------------------+------------+--------------+-----------------+----------------+-----------------+----------------+-----------------------+------------------------+---------------------+-----------------+----------------------+---------------------+-----------------+-------------------+-----------------+----------------+----------------+------------+---------------------+
|                2 | db2        | 01           | static_content  | ima_attribute  | ia              | MASTER         |                     1 |                      0 | 2000-01-01 00:00:00 | NULL            | NULL                 | NULL                |              -1 | db_delta          | db_stage        | ima_attribute  | InnoDB         | data_owner | 2011-12-08 19:01:31 |
+------------------+------------+--------------+-----------------+----------------+-----------------+----------------+-----------------------+------------------------+---------------------+-----------------+----------------------+---------------------+-----------------+-------------------+-----------------+----------------+----------------+------------+---------------------+

SET @sql_stmt = IF(@err_num <> 0,
                   CONCAT('SELECT "====> Create record about ''', @SRC_TABLE_NAME, ''' table : Error #', @err_num, 'AS "Error:" FROM dual'),
                   CONCAT('SELECT "====> Created record about ''', @SRC_TABLE_NAME, ''' table : OK" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

COMMIT;

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
