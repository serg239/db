/*
  Version:
    2011.12.11.01
  Script:
    25_create_proc_drop_info_link_fed_tables.sql
  Description:
    Create FEDERATED tables in ELT schema to connect to information_schema 
    tables on a given host (default shard_number '01').
  Input:
    * dst_schema_name     - Destination schema [elt|db_link|db_link_tmp|others]
    * host_alias          - Host Alias         [db1|db2]
    * debug_mode          - Debug Mode. Values:
                            * FALSE (0) - execute SQL statements
                            * TRUE  (1) - show SQL statements
  Output:
    * error_code:
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\25_create_proc_drop_info_link_fed_tables.sql
  Usage:
    CALL elt.drop_info_link_fed_tables (@err, 'db_link', TRUE);   -- display
    CALL elt.drop_info_link_fed_tables (@err, 'db_link', FALSE);  -- execute
*/
DELIMITER $$ 

DROP PROCEDURE IF EXISTS elt.drop_info_link_fed_tables$$ 

CREATE PROCEDURE elt.drop_info_link_fed_tables
(
 OUT error_code_out      INTEGER,
  IN dst_schema_name_in  VARCHAR(64),   -- DST Schema Name  [elt|db_link|db_link_tmp|others]
  IN debug_mode_in       BOOLEAN
) 
BEGIN

  DECLARE COL_FED_TABLE_NAME  VARCHAR(32) DEFAULT 'information_schema_columns';
  DECLARE IDX_FED_TABLE_NAME  VARCHAR(32) DEFAULT 'information_schema_indexes';

  DECLARE v_dst_schema_name   VARCHAR(64) DEFAULT dst_schema_name_in;
  DECLARE v_host_alias        VARCHAR(16);
  DECLARE v_sch_exists        BOOLEAN     DEFAULT FALSE;

  DECLARE done                BOOLEAN     DEFAULT FALSE;

  --
  -- Host Information
  --
  DECLARE hosts_cur CURSOR
  FOR
    SELECT spf.host_alias
      FROM elt.shard_profiles   spf
     WHERE shard_number = '01'          -- default 
       AND spf.status   = 1;            -- active shard

  -- 'NOT FOUND' Handler
  DECLARE CONTINUE HANDLER 
  FOR NOT FOUND 
  SET done = TRUE;

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF = CHAR(10);

  exec:
  BEGIN
    
    SET error_code_out = -2;

    OPEN hosts_cur;
   
    -- ================================
    hosts_loop:
    LOOP
      SET done = FALSE;

      FETCH hosts_cur
       INTO v_host_alias;

      IF NOT done THEN
        -- ==============================
        -- Columns
        -- ==============================
        SET @sql_stmt = CONCAT('DROP TABLE IF EXISTS ', v_dst_schema_name, '.', v_host_alias, '_', COL_FED_TABLE_NAME); 
        IF debug_mode_in THEN
          SELECT CONCAT(@LF, 
                        CAST(@sql_stmt AS CHAR), ";", 
                        @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
          -- SELECT CONCAT('====> Table ''', v_dst_schema_name, '.', v_host_alias, '_', COL_FED_TABLE_NAME, ''' has been dropped') AS "Info:" FROM dual;
        END IF;
        -- ==============================
        -- Indexes
        -- ==============================
        SET @sql_stmt = CONCAT('DROP TABLE IF EXISTS ', v_dst_schema_name, '.', v_host_alias, '_', IDX_FED_TABLE_NAME); 
        IF debug_mode_in THEN
          SELECT CONCAT(@LF, 
                        CAST(@sql_stmt AS CHAR), ";", 
                        @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
          -- SELECT CONCAT('====> Table ''', v_dst_schema_name, '.', v_host_alias, '_', IDX_FED_TABLE_NAME, ''' has been dropped') AS "Info:" FROM dual;
        END IF;
      ELSE
        LEAVE hosts_loop;
      END IF;

    END LOOP;
    -- ================================
    CLOSE hosts_cur;
    
    -- DROP Schema
    SET v_sch_exists = FALSE;
    SELECT TRUE 
      INTO v_sch_exists 
      FROM information_schema.schemata 
     WHERE schema_name = v_dst_schema_name;
    -- 
    IF v_sch_exists THEN
      SET @sql_stmt = CONCAT('DROP SCHEMA IF EXISTS ', v_dst_schema_name);
      IF debug_mode_in THEN
        SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF; 
    END IF;
    
    SET error_code_out = 0; 

  END;  -- exec:

  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;

END$$

DELIMITER ;

SELECT '====> Procedure ''drop_info_link_fed_tables'' has been created' AS "Info:" FROM dual;
