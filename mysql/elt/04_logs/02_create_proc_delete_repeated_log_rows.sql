/*
  Version:
    2011.11.16.01
  Script:
    02_create_proc_delete_repeated_log_rows.sql
  Description:
    Remove repeated values from the LOG tables in STAGE (first download) or DELTA (last download) schemas .
  Input:
    schema_name      - Schema Name. Values [STAGE | DELTA]
    debug_mode       - Debug Mode.
                       Values:
                         * 0 - show SQL statements  
                         * 1 - execute SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\02_create_proc_delete_repeated_log_rows.sql
  Usage:
    CALL elt.delete_repeated_rows (@err, 'STAGE', FALSE);    -- from all DB tables after the first download
    CALL elt.delete_repeated_rows (@err, 'DELTA', FALSE);    -- from all DELTA tables, net downloads
  Example:
    Table: account_log; Master PK ID = 0.
    SELECT * FROM elt.log_table_changes ORDER BY 1, 2;
    +-----------------+--------------------+---------------------+-------------+-------------------------------------+
    | log_table_pk_id | master_table_pk_id | log_created_dtm     | modified_id | row_value                           |
    +-----------------+--------------------+---------------------+-------------+-------------------------------------+
    |            5682 |                  0 | 2010-09-27 08:42:44 |          -1 | '0','1','SHC_WEB','NULL','NULL','1' |   <---
    +-----------------+--------------------+---------------------+-------------+-------------------------------------+
    |            5683 |                  0 | 2010-09-27 08:42:48 |          -1 | '0','1','SHC','NULL','NULL','5'     |   <---
    +-----------------+--------------------+---------------------+-------------+-------------------------------------+
    |            6443 |                  0 | 2011-02-24 10:06:07 |          -1 | '0','1','SHC','NULL','NULL','81'    |   <---
    |            7275 |                  0 | 2011-03-30 19:07:19 |          -1 | '0','1','SHC','NULL','NULL','81'    |
    |            8117 |                  0 | 2011-04-06 18:14:15 |          -1 | '0','1','SHC','NULL','NULL','81'    |
    |            8962 |                  0 | 2011-04-12 10:11:01 |          -1 | '0','1','SHC','NULL','NULL','81'    |
    |            9802 |                  0 | 2011-04-12 17:43:45 |          -1 | '0','1','SHC','NULL','NULL','81'    |
    |           10727 |                  0 | 2011-04-20 17:44:34 |          -1 | '0','1','SHC','NULL','NULL','81'    |
    |           11676 |                  0 | 2011-06-15 15:27:56 |          -1 | '0','1','SHC','NULL','NULL','81'    |
    |           12752 |                  0 | 2011-07-20 18:15:18 |          -1 | '0','1','SHC','NULL','NULL','81'    |
    +-----------------+--------------------+---------------------+-------------+-------------------------------------+
    |           13315 |                  0 | 2011-07-27 19:03:57 |          -1 | '0','1','SHC','NULL','NULL','65'    |   <---
    |           15183 |                  0 | 2011-09-07 17:46:02 |          -1 | '0','1','SHC','NULL','NULL','65'    |
    +-----------------+--------------------+---------------------+-------------+-------------------------------------+
    12 rows in set (0.00 sec)

    Not duplicated rows (4 from 12):
    +-----------------+
    | log_table_pk_id |
    +-----------------+
    |            5682 |
    |            5683 |
    |            6443 |
    |           13315 |
    +-----------------+
    4 rows in set (0.01 sec)
    Other rows will de deleted from account_log table.
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.delete_repeated_log_rows$$

CREATE PROCEDURE elt.delete_repeated_log_rows
(
  OUT error_code_out      INTEGER,
   IN schema_type_in      VARCHAR(16),  -- [STAGE|DELTA]
   IN debug_mode_in       BOOLEAN
)
BEGIN

  DECLARE STAGE_SCHEMA_TYPE           VARCHAR(16)  DEFAULT 'STAGE';            -- stage schema type
  DECLARE DELTA_SCHEMA_TYPE           VARCHAR(16)  DEFAULT 'DELTA';            -- delta schema type
  
  DECLARE PROC_SCHEMA_NAME            VARCHAR(64) DEFAULT 'elt';               -- control schema
  DECLARE STAGE_SCHEMA_NAME           VARCHAR(64) DEFAULT 'db_stage';          -- stage
  DECLARE DELTA_SCHEMA_NAME           VARCHAR(64) DEFAULT 'db_delta';          -- delta
  DECLARE LOG_DUPS_SCHEMA_NAME        VARCHAR(64) DEFAULT 'log_dups';          -- log_dups

  DECLARE MDF_ID_COL_NAME             VARCHAR(64) DEFAULT 'modified_id';       -- default   
  DECLARE MDF_DTM_COL_NAME            VARCHAR(64) DEFAULT 'modified_dtm';      -- default
  DECLARE CRT_DTM_COL_NAME            VARCHAR(64) DEFAULT 'created_dtm';       -- default 
  DECLARE LAST_MOD_TIME_COL_NAME      VARCHAR(64) DEFAULT 'last_mod_time';     -- in DB2.load_catalog schema
  DECLARE LOG_CRT_DTM_COL_NAME        VARCHAR(64) DEFAULT 'log_created_dtm';   -- default 
  DECLARE LOG_MDF_DTM_COL_NAME        VARCHAR(64) DEFAULT 'log_modified_dtm';  -- in DB1.account schema
  DECLARE VERSION_NUM_COL_NAME        VARCHAR(64) DEFAULT 'version_number';
  DECLARE COMMENTS_COL_NAME           VARCHAR(64) DEFAULT 'comments';

  DECLARE v_schema_type               VARCHAR(16);
  DECLARE v_dst_schema_name           VARCHAR(64);
 
  DECLARE v_download_num              INTEGER;

  DECLARE v_src_schema_name           VARCHAR(64);     -- DB LOG schema name
  DECLARE v_src_table_name            VARCHAR(64);     -- DB LOG table name
  DECLARE v_log_table_pk_column_name  VARCHAR(64);     -- Name of the PK in the DB LOG Table
  DECLARE v_dtm_column_name           VARCHAR(64);     -- log_modified_dtm OR log_created_dtm
  DECLARE v_dedup_block_size          INTEGER;
  DECLARE v_proc_pk_column_name       VARCHAR(64);     -- Name of the PK in the DB MASTER Table

  DECLARE v_column_name               VARCHAR(64);
  DECLARE v_table_column_def          TEXT;

  DECLARE v_pk_num                    INTEGER DEFAULT 0;
  DECLARE v_proc_num                  INTEGER DEFAULT 0;
  DECLARE v_rows_in_block_num         INTEGER DEFAULT 0;
  DECLARE v_deleted_rows_num          INTEGER DEFAULT 0;

  DECLARE v_block_offset_num          INTEGER DEFAULT 0;   -- v_block_offset_num = v_block_offset_num + v_dedup_block_size;
  DECLARE v_proc_rows_offset          INTEGER;             -- v_proc_rows_offset = v_proc_rows_offset + 1;  
  DECLARE v_process_timing_start      TIMESTAMP;
  DECLARE v_process_timing_end        TIMESTAMP;
  DECLARE v_process_duration          INTEGER     DEFAULT 0; 
  
  DECLARE v_tmp_filter_pk_tbl_name    VARCHAR(64);

  DECLARE v_column_str                VARCHAR(21800);  -- All acceptable row attriburtes as one string

  DECLARE done                        BOOLEAN DEFAULT FALSE;

  -- ==================================
  -- if table name is not defined - get all DB LOG tables
  -- and PK Column Name of MASTER and LOG Objects
  -- ==================================
  DECLARE db_log_tables_cur CURSOR
  FOR
  SELECT DISTINCT src.src_schema_name,
         src.src_table_name,
         isc.column_name                      AS log_table_pk_column_name,
         src.dtm_column_name,
         CASE WHEN (src.proc_block_size = 0) OR (src.proc_block_size = -1) THEN FLOOR(src.initial_rows/10)
              ELSE IF(src.proc_block_size > 100000, 
                      FLOOR(src.proc_block_size/10),
                      src.proc_block_size
                     )
         END                                  AS dedup_block_size, 
         src.proc_pk_column_name
    FROM elt.src_tables                      src
      INNER JOIN elt.control_downloads       cd
        ON src.src_table_id = cd.src_table_id
          AND cd.download_num    = v_download_num    -- first (STAGE) or last (STAGE/DELTA) download
          AND cd.download_status = 1                 -- downloaded
          AND cd.filter_status   = 0                 -- but not filtered yet
      INNER JOIN information_schema.columns  isc
        ON src.src_schema_name = isc.table_schema    -- DB schema name
          AND src.src_table_name  = isc.table_name    
   WHERE src.src_table_type = 'LOG'                  -- LOG tables only
     AND src.initial_rows   > 0                      -- not empty LOG table
     AND isc.column_key     = 'PRI'                  -- primary key column
   ORDER BY 1, 2;

  -- ==================================
  -- Statement for grouped columns of the DB LOG table
  -- ==================================
  DECLARE obj_columns_stmt_cur CURSOR
  FOR
  SELECT CONCAT(SUBSTR(q.tbl_cols, 1, LENGTH(tbl_cols) - 2), '\'')
    FROM 
      (SELECT GROUP_CONCAT(''''''''', IFNULL(', column_name, ',', '''NULL''), '''''',''') AS tbl_cols
         FROM information_schema.columns
        WHERE table_schema = v_src_schema_name
          AND table_name   = v_src_table_name
          AND column_name NOT IN (MDF_ID_COL_NAME, MDF_DTM_COL_NAME, CRT_DTM_COL_NAME, 
                                  LOG_CRT_DTM_COL_NAME, LOG_MDF_DTM_COL_NAME, LAST_MOD_TIME_COL_NAME, 
                                  VERSION_NUM_COL_NAME, COMMENTS_COL_NAME)
          AND column_name NOT LIKE '%_lower'
          AND column_key  != 'PRI'
        ORDER BY ordinal_position
      ) q;

  -- ==================================
  -- Columns from DB LOG table
  -- ==================================
  DECLARE obj_columns_cur CURSOR
  FOR
    SELECT CONCAT(CHAR(96),column_name,CHAR(96)) AS column_name
      FROM information_schema.columns
     WHERE table_schema = v_src_schema_name
       AND table_name   = v_src_table_name
     GROUP BY column_name, column_type, is_nullable, column_default
     ORDER BY ordinal_position;

  -- Handler
  DECLARE CONTINUE HANDLER
  FOR NOT FOUND 
  SET done = TRUE;
  
  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @sql_stmt = NULL;
  SET @LF       = CHAR(10); 

  exec:
  BEGIN
    
    SET v_schema_type = UPPER (schema_type_in);
    -- Define the DST schema name
    IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
      SET v_dst_schema_name = STAGE_SCHEMA_NAME;
    ELSEIF (v_schema_type = DELTA_SCHEMA_TYPE) THEN
      SET v_dst_schema_name = DELTA_SCHEMA_NAME;
    ELSE
      SELECT CONCAT('ERROR: Wrong Schema Type ''', schema_type_in, '''.') FROM dual; 
      SET error_code_out = -3;
      LEAVE exec;
    END IF;  

    SET error_code_out = -2;

    -- Get Current download #
    SELECT IFNULL(MAX(download_num), 0)
      INTO v_download_num
      FROM elt.control_downloads;

    IF (v_download_num > 0) THEN
      -- ================================== 
      -- Create table log_table_changes in MEMORY
      -- ================================== 
      -- Note: the maximum size of MEMORY tables is limited by the max_heap_table_size system variable, which has a default value of 16MB. 
      DROP TABLE IF EXISTS log_table_changes;
      CREATE TABLE log_table_changes
      (
        log_table_pk_id      BIGINT     NOT NULL,  -- (N) LOG table PK ID 
        master_table_pk_id   BIGINT     NOT NULL,  -- (1) MASTER (parent for the LOG table) table PK ID in the LOG table
        log_created_dtm      TIMESTAMP  NOT NULL,  -- log_created_dtm or log_modified_dtm
        modified_id          INTEGER,
        row_value            VARCHAR(21800),       -- Max Size: 21800 = 65535/3 [utf8] -2b [length] - (8+8+8+4+4)b [other columns] - 1b [NULL]
        INDEX USING BTREE (log_table_pk_id)
      )
      ENGINE = MEMORY;
      --
      -- Create Temporary table for MASTER table PK IDs
      --
      SELECT CONCAT("tmp_filter_pk_ids$", CAST(FLOOR(RAND() * 99999999999999) AS CHAR)) INTO v_tmp_filter_pk_tbl_name;
      SET @sql_stmt = CONCAT('CREATE TABLE IF NOT EXISTS ', LOG_DUPS_SCHEMA_NAME, '.', v_tmp_filter_pk_tbl_name,' (pk_id  BIGINT) ENGINE = InnoDB');
      IF debug_mode_in THEN
        SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF;

      -- Disable Logs
--    Note: only GLOBAL available, required SUPER privileges 
--    SET @old_general_log    = (SELECT @@GLOBAL.GENERAL_LOG);
--    SET @old_slow_query_log = (SELECT @@GLOBAL.SLOW_QUERY_LOG);
--    SET @@GLOBAL.GENERAL_LOG    = 'OFF';     -- SET @@GLOBAL.GENERAL_LOG    = 0;
--    SET @@GLOBAL.SLOW_QUERY_LOG = 'OFF';     -- SET @@GLOBAL.SLOW_QUERY_LOG = 0;

      OPEN db_log_tables_cur;              -- F(v_download_num=?, download_status = 1, filter_status = 0, LOG)
      -- ==============================
      -- Loop for all not empty LOG tables in a given schema
      --
      proc_log_tables:
      LOOP
        SET done = FALSE;
        FETCH db_log_tables_cur            -- F(v_download_num=?, download_status = 1, filter_status = 0, LOG)
         INTO v_src_schema_name,
              v_src_table_name, 
              v_log_table_pk_column_name, 
              v_dtm_column_name,
              v_dedup_block_size, 
              v_proc_pk_column_name;
/*
+--------------------+----------------------------------------+-------------------------------------------+------------------+------------------+---------------------------------------+
| log_schema_name    | log_table_name                         | log_table_pk_column_name                  | dtm_column_name  | dedup_block_size | proc_pk_column_name                   |
+--------------------+----------------------------------------+-------------------------------------------+------------------+------------------+---------------------------------------+
| account            | account_log                            | account_log_id                            | log_modified_dtm |            10000 | account_id                            |
| catalog            | content_item_asset_log                 | content_item_asset_log_id                 | log_created_dtm  |           100000 | content_item_asset_id                 |
| catalog            | content_item_build_instruction_log     | content_item_build_instruction_log_id     | log_created_dtm  |           100000 | content_item_build_instruction_id     |
| catalog            | content_item_external_item_mapping_log | content_item_external_item_mapping_log_id | log_created_dtm  |           100000 | content_item_external_item_mapping_id |
| catalog            | content_item_log                       | content_item_log_id                       | log_created_dtm  |           100000 | content_item_id                       |
| catalog            | item_log                               | item_log_id                               | log_created_dtm  |           100000 | item_id                               |
| catalog            | item_vendor_package_log                | item_vendor_package_log_id                | log_created_dtm  |           100000 | item_vendor_package_id                |
| semistatic_content | attribute_label_group_log              | attribute_label_group_log_id              | log_created_dtm  |            10000 | attribute_label_group_id              |
| semistatic_content | attribute_log                          | attribute_log_id                          | log_created_dtm  |            10000 | attribute_id                          |
| semistatic_content | attribute_value_log                    | attribute_value_log_id                    | log_created_dtm  |            10000 | attribute_value_id                    |
| semistatic_content | brand_log                              | brand_log_id                              | log_created_dtm  |            10000 | brand_id                              |
| semistatic_content | content_item_class_attribute_log       | content_item_class_attribute_log_id       | log_created_dtm  |            10000 | content_item_class_attribute_id       |
| semistatic_content | content_item_class_hierarchy_log       | content_item_class_hierarchy_log_id       | log_created_dtm  |            10000 | content_item_class_hierarchy_id       |
| semistatic_content | content_item_class_log                 | content_item_class_log_id                 | log_created_dtm  |            10000 | content_item_class_id                 |
| semistatic_content | hierarchy_log                          | hierarchy_log_id                          | log_created_dtm  |            10000 | hierarchy_id                          |
| semistatic_content | value_log                              | value_log_id                              | log_created_dtm  |            10000 | value_id                              |
| user               | user_log                               | user_log_id                               | log_modified_dtm |            10000 | user_id                               |
+--------------------+----------------------------------------+-------------------------------------------+------------------+------------------+---------------------------------------+
*/
        IF NOT done THEN
          -- ==============================
          -- Prepare SQL clause for grouped list of columns
          -- ==============================
          OPEN obj_columns_stmt_cur;                      -- F(v_src_schema_name, v_src_table_name)
          FETCH obj_columns_stmt_cur INTO v_column_str;
          IF debug_mode_in THEN
            SELECT CONCAT('Value: ', v_column_str) AS debug_sql; 
          END IF;
          CLOSE obj_columns_stmt_cur;
          -- ==============================
          
          -- ==============================
          -- COLUMNS = F(v_src_schema_name, v_src_table_name) -> v_table_column_def
          -- ==============================
          SET v_table_column_def = '';
          -- open different COLUMN cursors (information schema = F(DBn)) 
          OPEN obj_columns_stmt_cur;                     -- F(v_src_schema_name, v_src_table_name)
          -- ==============================
          src_db_columns:
          LOOP
            SET error_code_out = -2;
            SET done = FALSE;
            FETCH obj_columns_stmt_cur
             INTO v_column_name;
            -- check end of Loop (FETCH)
            IF done THEN
              SET error_code_out = 0;
              SET done = FALSE;
              LEAVE src_db_columns;
            END IF;
            --
            IF (v_table_column_def <> '') THEN
              SET v_table_column_def = CONCAT(v_table_column_def, ',', @LF);   -- add comma after the last column_def
            ELSE  
              SET v_table_column_def = '  ';
            END IF;
            --
            SET v_table_column_def = CONCAT(v_table_column_def, IF (v_table_column_def = '  ',  v_column_name, CONCAT('  ', v_column_name)));   -- name
            SET error_code_out = 0;
          END LOOP;  -- for all TABLE Columns
          -- ==============================
          -- close COLUMN cursor
          CLOSE obj_columns_stmt_cur;

          SET v_block_offset_num = 0;

          -- save AUTOCOMMIT mode
          SET @old_autocommit = (SELECT @@AUTOCOMMIT);
          SET @@AUTOCOMMIT = 0;

          -- ==============================
          -- For ALL Blocks
          -- ==============================
          proc_blocks:
          LOOP
            SET v_rows_in_block_num = 0;
            SET v_deleted_rows_num  = 0;
            -- Start Block Transaction 
            START TRANSACTION;
            -- Process start time
            SET v_process_timing_start = CURRENT_TIMESTAMP();
            -- Truncate Temp Table
            SET @sql_stmt = CONCAT('TRUNCATE TABLE ', LOG_DUPS_SCHEMA_NAME, '.', v_tmp_filter_pk_tbl_name);
            IF debug_mode_in THEN
              SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
            ELSE
              PREPARE query FROM @sql_stmt;
              EXECUTE query;
              DEALLOCATE PREPARE query;
            END IF;
            -- Populate Temp Table
            -- Get BASE Table PK IDs from the LOG table 
            SET @sql_stmt = CONCAT('INSERT INTO ', LOG_DUPS_SCHEMA_NAME, '.', v_tmp_filter_pk_tbl_name, ' (pk_id) ', 
                                   ' SELECT DISTINCT ', v_proc_pk_column_name, ' AS pk_id',
                                   ' FROM ', v_src_schema_name, '.', v_src_table_name, 
                                   ' ORDER BY 1', 
                                   ' LIMIT ', v_block_offset_num, ', ', v_dedup_block_size);      
            IF debug_mode_in  THEN
              SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
              SET v_pk_num = v_dedup_block_size;
            ELSE
              PREPARE query FROM @sql_stmt;
              EXECUTE query;
              -- Rows (Number of PK IDs in the current Block)
              SELECT ROW_COUNT() INTO v_pk_num;
              DEALLOCATE PREPARE query;
            END IF;
            -- Do we still have PK IDs
            IF (v_pk_num IS NOT NULL) AND (v_pk_num > 0) THEN
              -- 
              SET v_proc_rows_offset = 0;
              -- ==========================
              -- For ALL PK IDs in the Block
              -- ==========================
              proc_ids:
              LOOP
                --
                -- Get the Next Entry - MASTER table PK ID 
                --
                SET @sql_stmt = CONCAT('SELECT pk_id INTO @v_pk_id FROM ', LOG_DUPS_SCHEMA_NAME, '.', v_tmp_filter_pk_tbl_name, ' LIMIT ', v_proc_rows_offset, ', 1'); 
                IF debug_mode_in THEN
                  SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
                ELSE
                  PREPARE query FROM @sql_stmt;
                  EXECUTE query;
                  DEALLOCATE PREPARE query;
                END IF;

                IF (@v_pk_id IS NOT NULL) AND (v_proc_rows_offset < v_pk_num) THEN
                  -- Clear the log_table_changes table for new PK ID rows
                  TRUNCATE TABLE log_table_changes;
                  -- Insert all row_value for MASTER PK ID
                  SET @sql_stmt = CONCAT(
                  'INSERT INTO log_table_changes (log_table_pk_id, master_table_pk_id, log_created_dtm, modified_id, row_value) ', @LF,
                  'SELECT log.', v_log_table_pk_column_name, ' AS log_table_pk_id,',   @LF,
                  '       ', @v_pk_id, '                  AS master_table_pk_id,',   @LF,
                  '       log.', v_dtm_column_name, '     AS log_created_dtm,',     @LF,
                  '       log.modified_id                 AS modified_id,',         @LF,
                  '       CONCAT(', v_column_str, ')      AS row_value',            @LF,
                  ' FROM ', v_src_schema_name, '.', v_src_table_name, ' log',       @LF,
                  ' WHERE log.', v_proc_pk_column_name, ' = ', @v_pk_id,    @LF,
                  ' ORDER BY log.', v_log_table_pk_column_name, ', log.', v_dtm_column_name);
                  IF debug_mode_in THEN
                    SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
                  ELSE                
                    PREPARE query FROM @sql_stmt;
                    EXECUTE query;
                    -- Number of Rows for a given PK
                    SELECT ROW_COUNT() INTO v_proc_num;                          
                    SET v_rows_in_block_num = v_rows_in_block_num + v_proc_num;   -- Total Rows
                    DEALLOCATE PREPARE query;
                  END IF;
                  IF debug_mode_in THEN
                    SELECT CONCAT('Offsets[Block|Row]:', v_block_offset_num, '|', v_proc_rows_offset, '; PK: ', @v_pk_id, '; Rows: ', v_proc_num, '; Total in Block: ', v_rows_in_block_num) AS debug_rows;
                  END IF;

                  -- ==================
                  -- SAVE Duplicated Rows
                  -- ==================
                  SET @sql_stmt = CONCAT(
                   'INSERT INTO ', LOG_DUPS_SCHEMA_NAME, '.', v_src_table_name, @LF,
                   '(', @LF,
                   v_table_column_def, @LF,
                   ')', @LF,
                   ' SELECT ', v_table_column_def,                                 @LF,
                   ' FROM ', v_src_schema_name, '.', v_src_table_name,             @LF,
                   ' WHERE ', v_proc_pk_column_name, ' = ', @v_pk_id,              @LF,
                   '   AND ', v_log_table_pk_column_name, ' NOT IN ',              @LF,
                   '  (SELECT q1.log_table_pk_id ',                                @LF,  -- unrepeated values
                   '      FROM ',                                                  @LF,
                   '       (SELECT t1.*, ',                                        @LF,
                   '               COUNT(*)  AS rank ',                            @LF,
                   '          FROM log_table_changes               t1 ',           @LF,
                   '            LEFT OUTER JOIN log_table_changes  t2 ',           @LF,
                   '              ON t1.log_created_dtm >= t2.log_created_dtm',    @LF,
                   '         GROUP BY t1.log_created_dtm',                         @LF,
                   '       )  AS q1 ',                                             @LF,
                   '       LEFT OUTER JOIN ',                                      @LF,
                   '         (SELECT t1.*, ',                                      @LF,
                   '                 COUNT(*)  AS rank ',                          @LF,
                   '            FROM log_table_changes              t1 ',          @LF,
                   '              LEFT OUTER JOIN log_table_changes t2 ',          @LF,
                   '                ON t1.log_created_dtm >= t2.log_created_dtm ', @LF,
                   '           GROUP BY t1.log_created_dtm ',                      @LF,
                   '         ) AS q2',                                             @LF,
                   '         ON q1.rank = q2.rank + 1',                            @LF,
                   '           AND q1.row_value = q2.row_value',                   @LF,
                   '     WHERE q2.log_created_dtm IS NULL',                        @LF,
                   '     ORDER BY q1.log_created_dtm',                             @LF,
                   '   )'
                    );
                    IF debug_mode_in THEN
                      SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
                    ELSE
                      PREPARE query FROM @sql_stmt;
                      EXECUTE query;
                      -- Number of Deleted Rows for a given PK
                      SELECT ROW_COUNT() INTO v_proc_num;
                      SET v_deleted_rows_num = v_deleted_rows_num + v_proc_num;   -- Deleted Rows
                      DEALLOCATE PREPARE query; 
                      -- COMMIT; -- Not commit here
                    END IF;
                  -- ==================
                  -- Modify schema name
                  -- ==================
                  IF (v_schema_type = DELTA_SCHEMA_TYPE) THEN
                    SET v_src_schema_name = DELTA_SCHEMA_NAME;
                  END IF;  
                  -- ==================
                  -- Filter the result:  
                  -- DELETE FROM the LOG Table of a given schema
                  -- ==================
                  SET @sql_stmt = CONCAT(
                   'DELETE FROM ', v_src_schema_name, '.', v_src_table_name,       @LF,
                   ' WHERE ', v_proc_pk_column_name, ' = ', @v_pk_id,              @LF,
                   '   AND ', v_log_table_pk_column_name, ' NOT IN ',              @LF,
                   '  (SELECT q1.log_table_pk_id ',                                @LF,  -- unrepeated values
                   '      FROM ',                                                  @LF,
                   '       (SELECT t1.*, ',                                        @LF,
                   '               COUNT(*)  AS rank ',                            @LF,
                   '          FROM log_table_changes               t1 ',           @LF,
                   '            LEFT OUTER JOIN log_table_changes  t2 ',           @LF,
                   '              ON t1.log_created_dtm >= t2.log_created_dtm',    @LF,
                   '         GROUP BY t1.log_created_dtm',                         @LF,
                   '       )  AS q1 ',                                             @LF,
                   '       LEFT OUTER JOIN ',                                      @LF,
                   '         (SELECT t1.*, ',                                      @LF,
                   '                 COUNT(*)  AS rank ',                          @LF,
                   '            FROM log_table_changes              t1 ',          @LF,
                   '              LEFT OUTER JOIN log_table_changes t2 ',          @LF,
                   '                ON t1.log_created_dtm >= t2.log_created_dtm ', @LF,
                   '           GROUP BY t1.log_created_dtm ',                      @LF,
                   '         ) AS q2',                                             @LF,
                   '         ON q1.rank = q2.rank + 1',                            @LF,
                   '           AND q1.row_value = q2.row_value',                   @LF,
                   '     WHERE q2.log_created_dtm IS NULL',                        @LF,
                   '     ORDER BY q1.log_created_dtm',                             @LF,
                   '   )'
                    );
                    IF debug_mode_in THEN
                      SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
                    ELSE
                      PREPARE query FROM @sql_stmt;
                      EXECUTE query;
                      -- Number of Deleted Rows for a given PK
                      SELECT ROW_COUNT() INTO v_proc_num;
                      SET v_deleted_rows_num = v_deleted_rows_num + v_proc_num;   -- Deleted Rows
                      DEALLOCATE PREPARE query;
                      COMMIT;  -- Commit
                    END IF;

                    -- before append DELTA to STAGE:
                    -- get last (log_created_dtm, LOG_PK_ID) STAGE entry values 
                    -- and compare with first (log_created_dtm, LOG_PK_ID) DELTA entry 
                    -- if equal - delete the first DELTA entry and INSERT DELTA into STAGE
                    -- if not equal - INSERT DELTA into STAGE

                  -- Next BASE PK ID in the Block
                  SET v_proc_rows_offset = v_proc_rows_offset + 1;

                ELSE
                  -- IF (@v_pk_id IS NULL) OR (v_proc_rows_offset >= v_pk_num)
                  LEAVE proc_ids;
                END IF;
              END LOOP;  -- proc_ids
              -- ==========================
              -- Next Block of IDs
              SET v_block_offset_num = v_block_offset_num + v_dedup_block_size;    -- 0+40=40, 40+40=80;
            ELSE
              -- IF (v_pk_num = 0)
              LEAVE proc_blocks;
            END IF;  -- IF-ELSE (v_pk_num > 0)

            -- Process end time
            SET v_process_timing_end = CURRENT_TIMESTAMP();
            -- Duration
            SET v_process_duration = TIMESTAMPDIFF (SECOND, v_process_timing_start, v_process_timing_end);

            -- ==================================
            -- Mark that the whole block of BASE IDs in the LOG table have been processed
            -- ==================================
            -- Save final information about block processing
            SET @sql_stmt = CONCAT('INSERT INTO ', PROC_SCHEMA_NAME, '.repeated_log_records (download_num, schema_name, table_name, entries_num, total_rows, deleted_rows, proc_duration, created_by, created_at)', @LF,
                                   'SELECT ', v_download_num,      ' AS download_num,',   @LF,    -- Number of BASE PK IDs in the current Block
                                   '''', v_dst_schema_name, ''' AS schema_name,',         @LF,    -- Log Table Schema Name 
                                   '''', v_log_table_name,  ''' AS table_name,',          @LF,    -- Log Table Name (BASE PKs)
                                   v_pk_num,            ' AS entries_num,',               @LF,    -- Number of BASE PK IDs in the current Block
                                   v_rows_in_block_num, ' AS total_rows,',                @LF,    -- Total Number of Log Rows for all BASE PKs in a Block
                                   v_deleted_rows_num,  ' AS deleted_rows,',              @LF,    -- Number of Deleted Log Rows for all BASE PKs in a Block
                                   v_process_duration,  ' AS proc_duration,',             @LF,    -- Duration of Deletion process for a Block
                                   '''', SUBSTRING_INDEX(CURRENT_USER, "@", 1), ''' AS created_by,',    @LF,  
                                   '''', CURRENT_TIMESTAMP,  ''' AS created_at',          @LF,
                                   'FROM dual');
            IF debug_mode_in THEN
              SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
            ELSE                
              PREPARE query FROM @sql_stmt;
              EXECUTE query;
              DEALLOCATE PREPARE query;
            END IF;
            -- Commit Block Transaction
            COMMIT;
          END LOOP; -- proc_blocks
          -- ==============================
          -- restore AUTOCOMMIT mode
          SET @@AUTOCOMMIT = @old_autocommit;
        ELSE    
          LEAVE proc_log_tables;
        END IF;  -- IF-ELSE NOT done  
      
      END LOOP;  -- proc_log_tables
      -- ==============================
      CLOSE db_log_tables_cur;

      -- Drop Table of concatenated fields' values
      DROP TABLE IF EXISTS log_table_changes;

      -- Drop Temporary Table
      SET @sql_stmt = CONCAT('DROP TABLE IF EXISTS ', LOG_DUPS_SCHEMA_NAME, '.', v_tmp_filter_pk_tbl_name);
      IF debug_mode_in THEN
        SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
      ELSE                
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF;
      
/*      
  -- This should be done in the calling procedure (if wee have a set of filters):
      -- Update status
      UPDATE elt.control_downloads
         SET filter_status = 1,                    -- filtered
             modified_by     = SUBSTRING_INDEX(USER(), "@", 1),
             modified_at     = CURRENT_TIMESTAMP()
       WHERE download_num       = v_download_num   -- for current download
         AND cd.download_status = 1                -- downloaded
         AND filter_status      = 0                -- but not filtered yet
      ;         
*/
      -- restore MySQL Logs 
--      SET @@GLOBAL.GENERAL_LOG    = @old_general_log;
--      SET @@GLOBAL.SLOW_QUERY_LOG = @old_slow_query_log;
      SET error_code_out = 0;
    END IF;  -- IF (v_download_num > 0)
  END;  -- exec
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END
$$

DELIMITER ;

SELECT '====> Procedure ''delete_repeated_rows'' has been created' AS "Info:" FROM dual;
