/*
  Version:
    2011.11.12.01
  Script:
    17_create_proc_append_delta.sql
  Description:
    Append data from DELTA tables to STAGE tables.
    Truncate DELTA tables. 
  Input:
    * remove_dup_flag - Remove Duplicates Flag.
    * validate_flag   - Validate Flag.
    * debug_mode      - Debug Mode.
                        Values:
                          * FALSE (0) - execute SQL statements
                          * TRUE  (1) - show SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\17_create_proc_append_delta.sql
  Usage:
    CALL elt.append_delta (@err, FALSE, FALSE, FALSE); -- Append data from DELTA tables to STAGE tables, don't remove data duplicates, don't validate tables.
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.append_delta$$

CREATE PROCEDURE elt.append_delta
(
  OUT error_code_out      INTEGER,
   IN remove_dup_flag_in  BOOLEAN,
   IN validate_flag_in    BOOLEAN,
   IN debug_mode_in       BOOLEAN
)
BEGIN

  DECLARE DELTA_SCHEMA_TYPE      VARCHAR(16) DEFAULT 'DELTA';
  DECLARE DELTA_SCHEMA_NAME      VARCHAR(64) DEFAULT 'db_delta';

  DECLARE v_sch_exists           BOOLEAN DEFAULT FALSE;  -- 0
  DECLARE v_not_appended         BOOLEAN DEFAULT FALSE;  -- 0

  DECLARE v_control_download_id  INTEGER;  
  DECLARE v_host_alias           VARCHAR(16);
  DECLARE v_src_schema_name      VARCHAR(64);
  DECLARE v_src_table_name       VARCHAR(64);
  DECLARE v_proc_rows            INTEGER;

  DECLARE v_download_num         INTEGER;                -- last download number

  DECLARE done                   BOOLEAN DEFAULT FALSE;

  -- CONTROL tables
  DECLARE control_tables_cur CURSOR
  FOR
  SELECT control_download_id,
         host_alias,
         src_schema_name,
         src_table_name,
         proc_rows
    FROM elt.control_downloads
   WHERE control_type    = DELTA_SCHEMA_TYPE
     AND download_status = 1            -- processed
     AND append_status   = 0            -- not appended
     AND download_num    = v_download_num
   ORDER BY src_table_id
  ;

  -- Handler
  DECLARE CONTINUE HANDLER
  FOR NOT FOUND 
  SET done = TRUE;

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF       = CHAR(10); 
  SET @sql_stmt = '';

  -- ================================ 
  exec:
  BEGIN

    SET error_code_out = -2;

    -- Check if DELTA schema exists
    SET v_sch_exists = FALSE;
    SELECT TRUE 
      INTO v_sch_exists
      FROM information_schema.schemata 
     WHERE schema_name = DELTA_SCHEMA_NAME;
    IF NOT v_sch_exists THEN
      SELECT CONCAT('Schema ''', DELTA_SCHEMA_NAME, ''' does not exist.') AS Error;
      LEAVE exec;
    END IF;  

    -- Get Current download # -> v_download_num
    SELECT IFNULL(MAX(download_num), 0)
      INTO v_download_num
      FROM elt.control_downloads;

    -- Check for "not appended" tables -> v_not_appended
    SELECT IF (COUNT(*) > 0, 1, 0)
      INTO v_not_appended
      FROM elt.control_downloads
     WHERE download_num = v_download_num
       AND append_status = 0;

    IF (v_download_num > 0) AND (v_not_appended = 1) THEN

      OPEN control_tables_cur;

      -- ================================
      -- LOOP for All not appended DELTA tables
      -- ================================
      control_tables:
      LOOP
        SET done = FALSE;
        FETCH control_tables_cur
         INTO v_control_download_id,
              v_host_alias,
              v_src_schema_name,
              v_src_table_name,
              v_proc_rows;
        IF done THEN
          LEAVE control_tables;
        END IF;

        IF v_proc_rows > 0 THEN

          -- IF (remove_dup_flag IS NOT NULL) AND remove_dup_flag THEN
            -- ================================
            -- Remove Duplicates from DELTA tables before Append to STAGE
            -- ===============================
            -- CALL elt.delete_repeated_rows_in_log(@err_num, DELTA_SCHEMA_TYPE, v_src_table_name, debug_mode_in);
            -- IF @err_num <> 0 THEN 
            --   SET error_code_out = -5;
            --   LEAVE control_tables;
            -- END IF;
          -- END IF;  -- IF remove_dup_flag

          -- Append (INSERT IGNORE) data of DELTA table to STAGE table
          SET error_code_out = -6;
          SET @sql_stmt = CONCAT('INSERT IGNORE INTO ', v_src_schema_name, '.', v_src_table_name, @LF,
                                 ' SELECT * ', @LF,
                                 '   FROM ', DELTA_SCHEMA_NAME, '.', v_src_table_name, @LF
                                );
          IF debug_mode_in THEN
            SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
            COMMIT;
          END IF; 

        END IF;  -- IF v_proc_rows > 0
      
        SET error_code_out = 0;

      END LOOP;
      -- ================================
      CLOSE control_tables_cur;
  
      IF error_code_out = 0 THEN
        -- Change the append_status
        SET error_code_out = -7;
        UPDATE elt.control_downloads
           SET append_status = 1,
               modified_by   = SUBSTRING_INDEX(USER(), "@", 1),
               modified_at   = CURRENT_TIMESTAMP()
         WHERE download_num  = v_download_num
           AND append_status = 0;
        COMMIT;

      END IF;  -- IF error_code_out = 0 

    END IF;  -- IF (v_download_num > 0) AND (v_not_appended = 1)

    SET error_code_out = 0;

  END; -- exec

  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;

END $$

DELIMITER ;

SELECT '====> Procedure ''append_delta'' has been created' AS "Info:" FROM dual;
