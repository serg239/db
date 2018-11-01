/*
  Version:
    2011.12.08.01
  Script:
    refresh_feds.sql
  Description:
    * Recreate Federated tables linked to DB1/DB2 information_schemas
  Input:
    * debug_mode   - Debug Mode.
                     Values:
                       * TRUE  (1) - show SQL statements
                       * FALSE (0) - execute SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * -2: - Error
  Istall:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\refresh_feds.sql
  Usage:
    CALL mysql.refresh_feds (@err, TRUE);   -- display SQL only
    CALL mysql.refresh_feds (@err, FALSE);  -- execute statements
*/

DELIMITER $$

DROP PROCEDURE IF EXISTS mysql.refresh_feds$$

CREATE PROCEDURE mysql.refresh_feds
(
  OUT error_code_out  INTEGER,
   IN debug_mode_in   BOOLEAN
)
BEGIN

  DECLARE CTRL_SCHEMA_NAME  CHAR(3) DEFAULT 'elt'; 

  DECLARE DB1_HOST_ALIAS    CHAR(3) DEFAULT 'db1';
  DECLARE DB2_HOST_ALIAS    CHAR(3) DEFAULT 'db2';

  DECLARE COL_TABLE_NAME    VARCHAR(32) DEFAULT 'information_schema_columns';
  DECLARE IDX_TABLE_NAME    VARCHAR(32) DEFAULT 'information_schema_indexes';

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF = CHAR(10); 
     
  SET error_code_out = -2;

  -- ==================================
  -- DB1
  -- ==================================
  -- COLUMNS
  SET @sql_stmt = CONCAT('DROP TABLE IF EXISTS ', CTRL_SCHEMA_NAME, '.', DB1_HOST_ALIAS, '_', COL_TABLE_NAME); 
  IF debug_mode_in THEN
    SELECT CONCAT(@LF, 
                  CAST(@sql_stmt AS CHAR), ";", 
                  @LF) AS debug_sql;
  ELSE
    PREPARE query FROM @sql_stmt;
    EXECUTE query;
    DEALLOCATE PREPARE query;
    SELECT CONCAT('====> Table ''', CTRL_SCHEMA_NAME, '.', DB1_HOST_ALIAS, '_', COL_TABLE_NAME, ''' has been dropped') AS "Info:" FROM dual;
  END IF;

  -- INDEXES
  SET @sql_stmt = CONCAT('DROP TABLE IF EXISTS ', CTRL_SCHEMA_NAME, '.', DB1_HOST_ALIAS, '_', IDX_TABLE_NAME); 
  IF debug_mode_in THEN
    SELECT CONCAT(@LF, 
                  CAST(@sql_stmt AS CHAR), ";", 
                  @LF) AS debug_sql;
  ELSE
    PREPARE query FROM @sql_stmt;
    EXECUTE query;
    DEALLOCATE PREPARE query;
    SELECT CONCAT('====> Table ''', CTRL_SCHEMA_NAME, '.', DB1_HOST_ALIAS, '_', IDX_TABLE_NAME, ''' has been dropped') AS "Info:" FROM dual;
  END IF;
      
  -- Create FED tables for DB1
  CALL elt.create_info_link_tables (@err, DB1_HOST_ALIAS, debug_mode_in);  -- execute

  -- ==================================
  -- DB2
  -- ==================================
  -- COLUMNS
  SET @sql_stmt = CONCAT('DROP TABLE IF EXISTS ', CTRL_SCHEMA_NAME, '.', DB2_HOST_ALIAS, '_', COL_TABLE_NAME); 
  IF debug_mode_in THEN
    SELECT CONCAT(@LF, 
                  CAST(@sql_stmt AS CHAR), ";", 
                  @LF) AS debug_sql;
  ELSE
    PREPARE query FROM @sql_stmt;
    EXECUTE query;
    DEALLOCATE PREPARE query;
    SELECT CONCAT('====> Table ''', CTRL_SCHEMA_NAME, '.', DB2_HOST_ALIAS, '_', COL_TABLE_NAME, ''' has been dropped') AS "Info:" FROM dual;
  END IF;

  -- INDEXES
  SET @sql_stmt = CONCAT('DROP TABLE IF EXISTS ', CTRL_SCHEMA_NAME, '.', DB2_HOST_ALIAS, '_', IDX_TABLE_NAME); 
  IF debug_mode_in THEN
    SELECT CONCAT(@LF, 
                  CAST(@sql_stmt AS CHAR), ";", 
                  @LF) AS debug_sql;
  ELSE
    PREPARE query FROM @sql_stmt;
    EXECUTE query;
    DEALLOCATE PREPARE query;
    SELECT CONCAT('====> Table ''', CTRL_SCHEMA_NAME, '.', DB2_HOST_ALIAS, '_', IDX_TABLE_NAME, ''' has been dropped') AS "Info:" FROM dual;
  END IF;
      
  -- Create FED tables for DB1
  CALL elt.create_info_link_tables (@err, DB2_HOST_ALIAS, debug_mode_in);  -- execute

  SET error_code_out = 0;

  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;

END$$

DELIMITER ;

SELECT '====> Procedure ''refresh_feds'' has been created' AS "Info:" FROM dual;
