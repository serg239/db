/*
  Version:
    2011.12.11.01
  Script:
    21_create_proc_get_elt_data.sql
  Description:
    Create Log records for active and valid (check before copying) tables 
    and copy MASTER (first) and LOG (second) data from remote DB hosts 
    and schemas to STAGE or DELTA schema.
    ------------------------------
    ! Attn ! MASTER tables first !
    ------------------------------
  Input:
    * schema_type     - Schema Type. Values: [STAGE|DELTA]
    * validate        - Validate Flag.
    * debug_mode      - Debug Mode.
                        Values:
                          * FALSE (0) - execute SQL statements
                          * TRUE  (1) - show SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\21_create_proc_get_elt_data.sql
  Usage:
    CALL elt.get_elt_data (@err, 'STAGE', FALSE, FALSE); -- Copy all (or not uploaded) MASTER and LOG Tables into STAGE schema - execute, no validation
    CALL elt.get_elt_data (@err, 'DELTA', TRUE, FALSE);  -- Copy all (or not uploaded) MASTER and LOG Tables into DELTA schema - display SQL only, validate
   Notes:
     To download data for the last day:
       UPDATE elt.src_tables
          SET override_dtm = DATE_SUB(CURRENT_TIMESTAMP, INTERVAL 1 DAY)
        WHERE src_table_load_status  = 1
          AND src_table_valid_status = 1;
       -- CALL elt.get_elt_data (@err, 'DELTA', TRUE, FALSE);   -- TRUNK
       -- CALL elt.get_elt_data (@err, 'DELTA', FALSE, FALSE);  -- TEST
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.get_elt_data$$

CREATE PROCEDURE elt.get_elt_data
(
  OUT error_code_out  INTEGER,
   IN schema_type_in  VARCHAR(16),   -- [STAGE|DELTA]
   IN validate_in     BOOLEAN,
   IN debug_mode_in   BOOLEAN
)
BEGIN

  DECLARE LINK_SCHEMA_TYPE      VARCHAR(16)  DEFAULT 'LINK';       -- link schema type
  DECLARE STAGE_SCHEMA_TYPE     VARCHAR(16)  DEFAULT 'STAGE';      -- stage schema type
  DECLARE DELTA_SCHEMA_TYPE     VARCHAR(16)  DEFAULT 'DELTA';      -- delta schema type

  DECLARE PROC_SCHEMA_NAME      VARCHAR(64) DEFAULT 'elt';         -- control
  DECLARE LINK_SCHEMA_NAME      VARCHAR(64) DEFAULT 'db_link';     -- link
  DECLARE STAGE_SCHEMA_NAME     VARCHAR(64) DEFAULT 'db_stage';    -- stage
  DECLARE DELTA_SCHEMA_NAME     VARCHAR(64) DEFAULT 'db_delta';    -- delta

  DECLARE is_elt_running        TINYINT     DEFAULT 0;
  DECLARE v_schema_type         VARCHAR(16) DEFAULT schema_type_in;
  DECLARE v_last_download_time  TIMESTAMP;

  DECLARE v_sch_exists          BOOLEAN DEFAULT FALSE;  -- 0
  DECLARE v_not_finished        BOOLEAN DEFAULT FALSE;  -- 0

  DECLARE v_download_num        INTEGER;

  DECLARE v_beg_timestamp       DATETIME;
  DECLARE v_end_timestamp       DATETIME;

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  -- ================================ 
  exec:
  BEGIN

    SET v_schema_type = UPPER(v_schema_type);
    SET @err_num = 0;
    
    -- Check DST schema name
    IF (v_schema_type <> STAGE_SCHEMA_TYPE) AND
       (v_schema_type <> DELTA_SCHEMA_TYPE) THEN
      SELECT CONCAT('ERROR: Wrong Schema Type ''', v_schema_type, '''.') FROM dual; 
      SET error_code_out = -3;
      LEAVE exec;
    END IF;  
      
    SET error_code_out = -2;

    -- ================================
    -- Check the state of the previous ELT process
    -- ================================
    SET is_elt_running = 0;
    SELECT elt.check_if_elt_is_running (@err_num) INTO is_elt_running;
    IF is_elt_running = 1 THEN
      SET error_code_out = 0;
      SELECT '====>  WARNING: The previous ELT process did not finish yet' AS "Info:" FROM dual; 
      LEAVE exec;
    END IF;
    
    -- ==================================
    -- Last Download: v_last_download_time
    -- ==================================
    SELECT MAX(control_end_dtm) 
      INTO v_last_download_time
      FROM elt.control_downloads
     WHERE download_status = 1;

    -- Restriction on update frequency
    IF (v_last_download_time IS NULL) OR TIMESTAMPDIFF(HOUR, v_last_download_time, CURRENT_TIMESTAMP) >= 2 THEN 

      --                beg0=(last0-1h)         beg1       end0=(last0+2h)
      --   ----+----------+==========+----------+==========+----------+====
      --       |    1h    |    1h    |    1h    |    1h    |    1h    |
      --   ----+----------+==========+----------+==========+----------+====
      --                             last0                 last1=end0 
      
      -- ==================================
      -- Start time: v_beg_timestamp
      -- ==================================
      -- DAY:     2011-10-31 00:14:00 -> 2011-10-30 00:00:00
      -- 3 HOURS: 2011-10-31 13:30:00 -> 2011-10-31 10:30:00
      IF (v_last_download_time IS NULL) THEN
        -- First time: CURRENT, rounded to 30 min, SUB 1 DAY
        SET v_beg_timestamp = DATE_SUB(FROM_UNIXTIME(ROUND(UNIX_TIMESTAMP(CURRENT_TIMESTAMP())/(60*30))*(60*30)), INTERVAL 1 DAY);
      ELSEIF (HOUR(v_last_download_time) = 0)
          OR (HOUR(DATE_SUB(v_last_download_time, INTERVAL 1 HOUR)) = 0) THEN  
        -- HOUR = 0: MAX end_dtm, rounded to 30 min, SUB 1 DAY  
        SET v_beg_timestamp = DATE_SUB(FROM_UNIXTIME(ROUND(UNIX_TIMESTAMP(v_last_download_time)/(60*30))*(60*30)), INTERVAL 1 DAY);
      ELSE
        -- HOUR <> 0: MAX end_dtm, rounded to 30 min, SUB 1 HOUR
        SET v_beg_timestamp = DATE_SUB(FROM_UNIXTIME(ROUND(UNIX_TIMESTAMP(v_last_download_time)/(60*30))*(60*30)), INTERVAL 1 HOUR);
      END IF;  

      -- ==================================
      -- End time: v_end_timestamp
      -- ==================================
      -- Max Delay =45 min: 14:14:59 -> 13:30
      IF (v_last_download_time IS NULL) THEN
        -- First time: CURRENT, rounded to 30 min
        SET v_end_timestamp = FROM_UNIXTIME(ROUND(UNIX_TIMESTAMP(CURRENT_TIMESTAMP())/(60*30))*(60*30));
      ELSEIF (HOUR(v_last_download_time) = 0)
          OR (HOUR(DATE_SUB(v_last_download_time, INTERVAL 1 HOUR)) = 0) THEN  
        -- HOUR(v_last_download_time) = 0: LAST or CURRENT, rounded to 30 min, 24+[2]=26 HOURS
        IF TIMESTAMPDIFF(HOUR, v_last_download_time, CURRENT_TIMESTAMP) > 3 THEN
          SET v_end_timestamp = FROM_UNIXTIME(ROUND(UNIX_TIMESTAMP(CURRENT_TIMESTAMP)/(60*30))*(60*30));
        ELSE  
          SET v_end_timestamp = DATE_ADD(FROM_UNIXTIME(ROUND(UNIX_TIMESTAMP(v_last_download_time)/(60*30))*(60*30)), INTERVAL 2 HOUR);
        END IF;  
      ELSE
        -- HOUR(v_last_download_time) <> 0: LAST or CURRENT, rounded to 30 min, ADD 2 HOURs
        IF TIMESTAMPDIFF(HOUR, v_last_download_time, CURRENT_TIMESTAMP) > 3 THEN
          SET v_end_timestamp = FROM_UNIXTIME(ROUND(UNIX_TIMESTAMP(CURRENT_TIMESTAMP)/(60*30))*(60*30));
        ELSE
          SET v_end_timestamp = DATE_ADD(FROM_UNIXTIME(ROUND(UNIX_TIMESTAMP(v_last_download_time)/(60*30))*(60*30)), INTERVAL 2 HOUR);
        END IF;  
      END IF;

      -- Get Current download #
      SELECT IFNULL(MAX(download_num), 0)
        INTO v_download_num
        FROM elt.control_downloads;

      IF (v_download_num > 0) THEN
        -- Mark last already processed tables as downloaded
        UPDATE elt.control_downloads
           SET download_status = 1,
               append_status   = IF(v_download_num = 1, 1, append_status)
         WHERE download_status = 0
           AND download_num = v_download_num
           AND (proc_rows > 0 
             OR proc_duration > 0);
        COMMIT;   
        -- Check for "not finished" tables
        SELECT IF (COUNT(*) > 0, 1, 0)
          INTO v_not_finished
          FROM elt.control_downloads
         WHERE download_num = v_download_num
           AND download_status = 0;
        -- AND TIMESTAMPDIFF (HOUR, control_end_dtm, CURRENT_TIMESTAMP) <= 24
      END IF;

      IF (v_not_finished = 0) THEN

        IF (validate_in IS NOT NULL) AND validate_in THEN
          -- ================================
          -- Validate SRC Tables
          --   check (and modify status) if SRC tables are valid for migration
          -- ===============================
          CALL elt.validate_src_tables (@err_num, NULL, NULL, NULL, FALSE);  -- all DB Hosts, all SRC schemas, all SRC tables
          IF (@err_num <> 0) THEN 
            LEAVE exec;
          END IF;
          -- ================================
          -- Fix conditions for table which are not valid for migration:
          -- if "There is no PK on Master table"         -> change proc_block_size to 0 (no blocks)
          -- if "There is no column for data processing" -> change proc_block_size to -1 (copy entire table)
          -- ===============================
          CALL elt.fix_cond_for_not_valid_tables (@err_num, FALSE);  -- all tables
          IF (@err_num <> 0) THEN 
            LEAVE exec;
          END IF;
        END IF;  -- IF (validate_in IS NOT NULL) AND validate_in 

        -- Go to the next download
        SET v_download_num = v_download_num + 1;

        -- ==================================
        -- Prepare list of Tables for LOG Data Import
        -- ==================================
        INSERT INTO elt.control_downloads
        (
          download_num,
          src_table_id,
          host_alias,              -- [db1|db2]
          shard_number,            -- [01|02|...]
          src_schema_name,
          src_table_name,
          download_status,         -- 0
          control_type,            -- [STAGE|DELTA]
          control_start_dtm,       -- Date Range Start
          control_end_dtm,         --            End 
          where_clause,
          order_by_clause,
          created_by,
          created_at
        )
        SELECT v_download_num,
               st.src_table_id,
               st.host_alias,
               st.shard_number,
               st.src_schema_name,
               st.src_table_name,
               0,                                            -- download_status = 0 - not downloaded
               v_schema_type         AS control_type,        -- [STAGE|DELTA]
               LEAST(v_beg_timestamp, IFNULL(st.override_dtm, '9999-12-31')) AS control_start_dtm, -- BETWEEN start_date MIN(MAX(control_downloads.control_start_dtm), src_tables.override_dtm)
               v_end_timestamp                                               AS control_end_dtm,   --     AND end_date   (CURRENT_TIMESTAMP)
               st.where_clause,
               st.order_by_clause,
               SUBSTRING_INDEX(USER(), "@", 1) AS created_by,
               CURRENT_TIMESTAMP()             AS created_at
          FROM elt.src_tables              st
            INNER JOIN elt.shard_profiles  spf
              ON st.shard_profile_id = st.shard_profile_id
                AND spf.status = 1
         WHERE st.src_table_load_status  = 1   -- active
           AND st.src_table_valid_status = 1   -- valid
           AND st.src_table_name <> spf.shard_table_name   -- shard_account_list table should be created in LINK schema only
         ORDER BY st.src_table_id;

        COMMIT;

      END IF;  

      -- save AUTOCOMMIT mode
      -- SET @old_autocommit = (SELECT @@AUTOCOMMIT);
      -- SET @@AUTOCOMMIT = 0;

      -- ==================================
      -- CHECK/CREATE "db_links" schema
      -- Drop/create shard table(s) in LINK schema
      -- ==================================
      -- Check if LINK schema exists
      SET v_sch_exists = FALSE;
      SELECT TRUE 
        INTO v_sch_exists 
        FROM information_schema.schemata 
       WHERE schema_name = LINK_SCHEMA_NAME;
      -- 
      IF NOT v_sch_exists THEN
        -- Create LINK schema with shard tables
        CALL elt.create_elt_schema (@err_num, LINK_SCHEMA_TYPE, debug_mode_in);
        IF (@err_num <> 0) THEN
          SELECT CONCAT('Procedure \'create_elt_schema\', schema ''', LINK_SCHEMA_TYPE, ''', ERROR: ', @err_num);
        END IF;
      END IF;

      -- ==================================
      -- DROP/CREATE "db_stage" or "db_delta" schemas (new Columns, Indexes):
      --   DROP SCHEMA db_stage
      --   CREATE SCHEMA db_stage
      --   CREATE TABLEs                           - from elt.src_tables
      --          COLUMNs, type, nullable, default - from source tables (information_schema of the remote DBs)
      --          INDEXes                          - from source tables (information_schema of the remote DBs)
      -- ==================================
      SET v_sch_exists = FALSE;
      IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
        -- Check if STAGE schema exists (continuing data migration)
        SELECT TRUE 
          INTO v_sch_exists
          FROM information_schema.schemata 
         WHERE schema_name = STAGE_SCHEMA_NAME;
        --
        IF NOT v_sch_exists THEN
          -- Drop/Create STAGE schema and tables
          CALL elt.create_elt_schema (@err_num, STAGE_SCHEMA_TYPE, debug_mode_in);
          IF (@err_num <> 0) THEN
            SELECT CONCAT('Procedure \'create_elt_schema\', schema ''', STAGE_SCHEMA_TYPE, ''', ERROR: ', @err_num) AS "ERROR";
          END IF;
        END IF;  
      ELSE
        -- Check if DELTA schema exists (continuing data migration)
        SELECT TRUE 
          INTO v_sch_exists
          FROM information_schema.schemata 
         WHERE schema_name = DELTA_SCHEMA_NAME;
        --
        IF NOT v_sch_exists THEN
          -- Drop/Create STAGE schema and tables
          CALL elt.create_elt_schema (@err_num, DELTA_SCHEMA_TYPE, debug_mode_in);
          IF (@err_num <> 0) THEN
            SELECT CONCAT('Procedure \'create_elt_schema\', schema ''', DELTA_SCHEMA_TYPE, ''', ERROR: ', @err_num) AS "ERROR";
          END IF;
        END IF;  
      END IF; -- IF-ELSE (v_schema_type = STAGE_SCHEMA_TYPE)

      -- ==================================
      -- Load_data:
      -- INSERT INTO <stage/delta_table> SELECT FROM <link_table> WHERE
      --    modified_dtm BETWEEN <start_dtm, end_dtm>
      -- OR log_created_dtm BETWEEN <start_dtm, end_dtm>
      -- ================================
      CALL elt.load_elt_data (@err_num, v_schema_type, debug_mode_in);
      -- ================================
      IF (@err_num = 0) THEN
        -- Change the download_status for all tables and current download in CONTROL table
        UPDATE elt.control_downloads
           SET download_status = 1
         WHERE download_num    = v_download_num
           AND download_status = 0;
        -- Clear Override datetime for all tables in SRC table
        UPDATE elt.src_tables
           SET override_dtm = NULL
         WHERE override_dtm IS NOT NULL;
        COMMIT;
      ELSE
        SELECT CONCAT('Procedure \'load_elt_data\', schema ''', v_schema_type, ''', ERROR: ', @err_num) AS "ERROR";
      END IF;

      -- restore AUTOCOMMIT mode
      -- SET @@AUTOCOMMIT = @old_autocommit;

      -- ==============================
      -- Drop LINK schema
      -- ==============================
      SET @sql_stmt = CONCAT('DROP SCHEMA IF EXISTS ', LINK_SCHEMA_NAME);
      IF debug_mode_in THEN
        SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF; 

      -- ==============================
      -- Filter STAGE or DELTA LOG values
      -- ==============================
      IF (v_schema_type = DELTA_SCHEMA_TYPE) THEN
        -- ==============================
        -- Append DELTA to STAGE
        -- ==============================
        -- Append data from DELTA tables to STAGE tables:
        --   don't remove data duplicates;
        --   don't validate tables
        CALL elt.append_delta (@err_num, FALSE, FALSE, debug_mode_in);
        -- ==============================
        IF (@err_num = 0) THEN
          -- ==============================
          -- Drop DELTA schema
          -- ==============================
          SET @sql_stmt = CONCAT('DROP SCHEMA IF EXISTS ', DELTA_SCHEMA_NAME);
          IF debug_mode_in THEN
            SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
          END IF; 
        ELSE
          SELECT CONCAT('Procedure \'append_delta\', ERROR: ', @err_num) AS "ERROR";
        END IF;
      END IF;  
      
    ELSE

      SELECT CONCAT('The last download time is ''', v_last_download_time, '''. The minimal update interval could not be less then 3 hours.') AS "WARNING";

    END IF;  -- IF-ELSE (v_last_download_time IS NULL) OR TIMESTAMPDIFF(HOUR, v_last_download_time, CURRENT_TIMESTAMP) >= 2

    SET error_code_out = 0;

  END; -- exec    

  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;

END $$

DELIMITER ;

SELECT '====> Procedure ''get_elt_data'' has been created' AS "Info:" FROM dual;
