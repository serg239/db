/*
  Version:
    2011.11.12.01
  Script:
    11_create_proc_get_appended_rows.sql
  Description:
    Get information about the number of appended rows.
  Input:
    * download_num    - Download Number: if NULL - last download
    * debug_mode      - Debug Mode.
                        Values:
                          * FALSE (0) - execute SQL statements
                          * TRUE  (1) - show SQL statements
  Output:
    * Concatenated string (table name; rows; duration)
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\11_create_proc_get_appended_rows.sql
  Usage:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd>  -e "CALL elt.get_appended_rows (@err, 5, @res_str, FALSE); SELECT @res_str;"
  Result:
    +----------------------------------------------------------------+
    | Download # 5; Rows= 698; Duration= 556 sec; Appended Rows= 666 |
    +----------------------------------------------------------------+
  Usage:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> -e "CALL elt.get_appended_rows (@err, 3, @res_str, FALSE); SELECT @res_str;"
  Result:
    +----------------------------------------------------------------+
    | Download # 3; Rows= 404; Duration= 565 sec; Appended Rows= 402 |
    +----------------------------------------------------------------+    
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.get_appended_rows$$ 

CREATE PROCEDURE elt.get_appended_rows 
( 
  OUT error_code_out  INTEGER,
   IN download_num_in INTEGER,
  OUT res_str_out     VARCHAR(128),
   IN debug_mode_in   BOOLEAN
)
BEGIN

  DECLARE DB1_HOST_ALIAS        VARCHAR(16) DEFAULT 'db1';
  DECLARE DB2_HOST_ALIAS        VARCHAR(16) DEFAULT 'db2';

  DECLARE DELTA_SCHEMA_TYPE     VARCHAR(16) DEFAULT 'DELTA';

  DECLARE STAGE_SCHEMA_NAME     VARCHAR(64) DEFAULT 'db_stage';
  DECLARE DELTA_SCHEMA_NAME     VARCHAR(64) DEFAULT 'db_delta';
  
  DECLARE v_src_table_name      VARCHAR(64);
  DECLARE v_dtm_column_name     VARCHAR(64);
  DECLARE v_proc_pk_column_name VARCHAR(64);
  DECLARE v_control_start_dtm   DATETIME;
  DECLARE v_control_end_dtm     DATETIME;
  DECLARE v_proc_rows           INTEGER;
  DECLARE v_proc_duration       INTEGER; 

  DECLARE v_appd_rows           INTEGER DEFAULT 0;
  DECLARE v_calc_rows           INTEGER DEFAULT 0;
  DECLARE v_calc_duration       INTEGER DEFAULT 0;

  DECLARE v_res_str             VARCHAR(128) DEFAULT "";

  DECLARE v_download_num        INTEGER;
  DECLARE done                  BOOLEAN      DEFAULT FALSE;

  -- APPENDED tables
  DECLARE appended_tables_cur CURSOR
  FOR
  SELECT st.src_table_name,
         st.dtm_column_name,
         st.proc_pk_column_name,
         cd.control_start_dtm,
         cd.control_end_dtm,
         cd.proc_rows,
         cd.proc_duration
    FROM elt.control_downloads   cd
      INNER JOIN elt.src_tables  st
        ON cd.src_table_id = st.src_table_id 
   WHERE cd.control_type    = DELTA_SCHEMA_TYPE
     AND cd.download_status = 1            -- processed
     AND cd.append_status   = 1            -- appended
     AND cd.download_num    = v_download_num
   ORDER BY st.src_table_id
  ;

  DECLARE CONTINUE HANDLER
  FOR NOT FOUND 
  SET done = TRUE;

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF       = CHAR(10); 
  SET @sql_stmt = '';

  IF download_num_in IS NULL THEN
    -- Get Current download #
    SELECT IFNULL(MAX(download_num), 0)
      INTO v_download_num
      FROM elt.control_downloads;
  ELSE
    SET v_download_num = download_num_in;
  END IF;    

  IF (v_download_num > 0) THEN
    -- LOOP for All Tables of the last download
    OPEN appended_tables_cur;
    -- ================================
    appended_tables:
    LOOP
      SET done = FALSE;
      FETCH appended_tables_cur
       INTO v_src_table_name,
            v_dtm_column_name,
            v_proc_pk_column_name,
            v_control_start_dtm,
            v_control_end_dtm,
            v_proc_rows,
            v_proc_duration;
      IF NOT done THEN
        SET @sql_stmt = CONCAT('SELECT COUNT(', v_proc_pk_column_name,' ) INTO @rows', @LF,
                               '  FROM ', STAGE_SCHEMA_NAME, '.', v_src_table_name, @LF,
                               ' WHERE ', v_dtm_column_name, ' BETWEEN \'', v_control_start_dtm, '\' AND \'', v_control_end_dtm, '\''
                              );
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF;

        SET v_appd_rows     = v_appd_rows + @rows;                 -- appended rows (appended rows <= populated rows)
        SET v_calc_rows     = v_calc_rows + v_proc_rows;           -- populated rows
        SET v_calc_duration = v_calc_duration + v_proc_duration;

      ELSE
        LEAVE appended_tables;
      END IF;
    END LOOP;  
    -- ================================
    CLOSE appended_tables_cur;
    
    SET res_str_out = CONCAT("Download # ",  v_download_num,
                             "; Rows= ",          FORMAT(v_calc_rows, 0),
                             "; Duration= ",      FORMAT(v_calc_duration, 0), " sec",
                             "; Appended Rows= ", FORMAT(v_appd_rows, 0)
                            );
  END IF;  -- IF (v_download_num > 0)
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END$$ 

DELIMITER ; 

SELECT '====> Procedure ''get_appended_rows'' has been created' AS "Info:" FROM dual;
