/*
  Version:
    2011.11.12.01
  Script:
    19_create_proc_get_initial_rows.sql
  Description:
    Get number of rows in all (or given) table(s) defined in elt.src_tables table. 
  Input:
    * src_schema_name    - SRC Schema Name (NULL if all tables/records in src_tables) 
    * src_table_name     - SRC Table Name  (NULL if all tables) 
    * recalc_continue    - Values:
                           * TRUE (1) - Recalculate
                           * FALSE (0)- Continue if initial_rows > 0
    * debug_mode         - Debug Mode.
                           Values:
                             * FALSE (0) - execute SQL statements
                             * TRUE  (1) - show SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\19_create_proc_get_initial_rows.sql
  Usage:  
    CALL elt.get_initial_rows (@err, 'account', 'account', TRUE, FALSE);   -- one table, recalculate
    CALL elt.get_initial_rows (@err, NULL, NULL, FALSE, FALSE);            -- all tables, continue
  Notes: 
    1. Errors from Server: 
       ERROR 1430 (HY000) at line 1: : 2006 : MySQL server has gone away
    2. Statement: 
       SELECT COUNT(*) FROM db_link.db1_01_account_account;
*/

DELIMITER $$ 

DROP PROCEDURE IF EXISTS elt.get_initial_rows$$

CREATE PROCEDURE elt.get_initial_rows
(
 OUT error_code_out     INTEGER,
  IN src_schema_name_in VARCHAR(64),   -- could be NULL
  IN src_table_name_in  VARCHAR(64),   -- could be NULL (all tables) 
  IN recalc_continue    BOOLEAN,
  IN debug_mode_in      BOOLEAN
) 
BEGIN

  DECLARE LINK_SCHEMA_NAME    VARCHAR(64) DEFAULT 'db_link';
  DECLARE THRESHOLD_NUM_ROWS  INTEGER     DEFAULT 0;    -- or 1000000 ???
 
  DECLARE v_host_alias        VARCHAR(16);              -- [db1|db2]
  DECLARE v_shard_number      CHAR(2);                  -- [01|02|...]
  DECLARE v_src_schema_name   VARCHAR(64) DEFAULT src_schema_name_in;
  DECLARE v_src_table_name    VARCHAR(64) DEFAULT src_table_name_in;

  DECLARE is_schema_exists    BOOLEAN DEFAULT FALSE;

  DECLARE done                BOOLEAN DEFAULT FALSE;

  --
  -- All tables
  --
  DECLARE main_src_tables_cur CURSOR
  FOR
  SELECT st.host_alias,             -- [db1|db2]
         st.shard_number,           -- [01|02|...]  
         st.src_schema_name,
         st.src_table_name
    FROM elt.src_tables              st
   WHERE st.src_table_load_status = 1  -- only active SRC tables
   ORDER BY st.src_table_id
  ;

  --
  -- Given table
  --
  DECLARE main_src_table_cur CURSOR
  FOR
  SELECT st.host_alias,             -- [db1|db2]
         st.shard_number            -- [01|02|...]  
    FROM elt.src_tables              st
   WHERE st.src_table_load_status = 1  -- only active SRC table
     AND st.src_schema_name       = v_src_schema_name
     AND st.src_table_name        = v_src_table_name
   ORDER BY st.src_table_id
  ;

  -- Handler
  DECLARE CONTINUE HANDLER
  FOR NOT FOUND 
  SET done = TRUE;
  
  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF = CHAR(10); 

  -- ================================ 
  exec:
  BEGIN
    -- Check if LINK schema exists
    SELECT TRUE 
      INTO is_schema_exists 
      FROM information_schema.schemata 
     WHERE schema_name = LINK_SCHEMA_NAME;
    IF NOT is_schema_exists  THEN
      SELECT CONCAT('The LINK schema does not exist') AS "ERROR" FROM dual;
      SET error_code_out = -4;
      LEAVE exec;
    END IF;  

    -- Open cursor
    IF (src_schema_name_in IS NULL) AND (src_table_name_in IS NULL) THEN
      OPEN main_src_tables_cur;
    ELSEIF (src_schema_name_in IS NOT NULL) AND (src_table_name_in IS NOT NULL) THEN
      OPEN main_src_table_cur;
    ELSE
      SELECT CONCAT('Schema [', src_schema_name_in, '] Name OR Table Name [', src_table_name_in, '] is not defined') AS "ERROR" FROM dual;
      SET error_code_out = -3;
      LEAVE exec;
    END IF;

    SET error_code_out = -2;

    -- ================================
    -- For All Tables or a given Table
    -- ================================
    main_src_tables:
    LOOP
      SET done = FALSE;
      IF (src_schema_name_in IS NULL) AND (src_table_name_in IS NULL) THEN
        -- all tables
        FETCH main_src_tables_cur
         INTO v_host_alias,             -- [db1|db2]
              v_shard_number,           -- [01|02|...]
              v_src_schema_name,
              v_src_table_name;
      ELSE
        -- given schema.table
        FETCH main_src_table_cur
         INTO v_host_alias,             -- [db1|db2]
              v_shard_number;           -- [01|02|...]
      END IF;
      -- 
      IF (v_host_alias IS NULL) OR (v_shard_number IS NULL) THEN
        SELECT "Couldn't get information about SRC tables. Check 'status' of the Host Profiles or 'load_status' of the SRC tables." AS "ERROR" FROM dual;
        SET error_code_out = -5;
        LEAVE main_src_tables;
      END IF;
      IF done THEN
        LEAVE main_src_tables;
      END IF;

      recalc:
      BEGIN
        -- ======================================================================
        -- Do we need recalculate the number of rows?
        -- ======================================================================
        IF NOT recalc_continue THEN
          -- FALSE (0)- Continue [do not SELECT COUNT(*)] if initial_rows > 0
          SET @curr_num_rows = 0;
          SELECT initial_rows 
            INTO @curr_num_rows
            FROM elt.src_tables
           WHERE src_table_load_status = 1  -- only active SRC tables
            AND host_alias      = v_host_alias
            AND shard_number    = v_shard_number
            AND src_schema_name = v_src_schema_name
            AND src_table_name  = v_src_table_name;
          IF @curr_num_rows > THRESHOLD_NUM_ROWS THEN
            LEAVE recalc;
          END IF;
        END IF;
        -- ======================================================================
        -- Get number of rows in the [sharded] table
        -- ======================================================================
        SET @shard_num_rows = 0;

        SET @sql_stmt = CONCAT(@LF,
          'SELECT COUNT(*)', @LF,
          '  INTO @shard_num_rows', @LF,
          '  FROM ', LINK_SCHEMA_NAME, '.', v_host_alias, '_', v_shard_number, '_', v_src_schema_name, '_', v_src_table_name);
        --   
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF;
        -- update number of rows
        SET @sql_stmt = CONCAT(@LF,
          'UPDATE elt.src_tables', @LF,
          '   SET initial_rows = @shard_num_rows,', @LF,
          '       modified_by       = ''', SUBSTRING_INDEX(USER(), "@", 1), ''',', @LF,
          '       modified_at       = ''', CURRENT_TIMESTAMP(), '''', @LF,
          ' WHERE host_alias      = ''', v_host_alias, '''', @LF,
          '   AND shard_number    = ''', v_shard_number, '''', @LF, 
          '   AND src_schema_name = ''', v_src_schema_name, '''', @LF,
          '   AND src_table_name  = ''', v_src_table_name, '''');
        -- 
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
          COMMIT;
        END IF;
      END;  -- recalc:
      SET error_code_out = 0; 
    END LOOP;  -- main_src_tables
    -- ================================
    -- close cursor
    IF (src_schema_name_in IS NULL) AND (src_table_name_in IS NULL) THEN
      CLOSE main_src_tables_cur;
    ELSE
      CLOSE main_src_table_cur;
    END IF;
  END;  -- exec:  
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END$$

DELIMITER ;

SELECT '====> Procedure ''get_initial_rows'' has been created' AS "Info:" FROM dual;
