/*
  Version:
    2012.01.16.01
  Script:
    28_truncate_unused_tables.sql
  Description:
    Truncate log tables not described in src_tables table.
-- ====================================
  Input:
    * debug_mode   - Debug Mode.
                     Values:
                       * TRUE  (1) - show SQL statements
                       * FALSE (0) - execute SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * -2: - Error
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.truncate_unused_tables$$

CREATE PROCEDURE elt.truncate_unused_tables
(
  OUT error_code_out  INTEGER,
   IN debug_mode_in   BOOLEAN
)
BEGIN
  
  DECLARE truncate_stmt         VARCHAR(256);

  DECLARE done                  BOOLEAN DEFAULT FALSE;

  DECLARE truncate_log_table_stmts_cur CURSOR 
  FOR
  SELECT CONCAT("TRUNCATE TABLE ", table_schema, ".", table_name) AS stmt
    FROM information_schema.tables 
   WHERE table_schema in ("account", "user", "load_catalog", "static_catalog", "semistatic_catalog", "external_account", "catalog") 
     AND (table_schema, table_name) NOT IN 
      (SELECT src_schema_name, 
              src_table_name 
         FROM elt.src_tables
       )
     AND table_name LIKE "%_log"
   ORDER BY table_schema, table_name;

  DECLARE truncate_table_stmts_cur CURSOR 
  FOR
  SELECT CONCAT("TRUNCATE TABLE ", table_schema, ".", table_name) AS stmt
    FROM information_schema.tables 
   WHERE table_schema in ("account", "user", "load_catalog", "static_catalog", "semistatic_catalog", "external_account", "catalog") 
     AND (table_schema, table_name) NOT IN 
      (SELECT src_schema_name, 
              src_table_name 
         FROM elt.src_tables
       )
     AND table_name NOT LIKE "%_log"
   ORDER BY table_schema, table_name;
 
  DECLARE CONTINUE HANDLER 
  FOR NOT FOUND 
  SET done = TRUE;

  SET error_code_out = -2;

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF = CHAR(10); 

  OPEN truncate_log_table_stmts_cur;
  -- ==================================
  truncate_log_table_stmts:
  LOOP
    SET done = FALSE;
    FETCH truncate_log_table_stmts_cur
     INTO truncate_stmt; 
    IF NOT done THEN
      SET @sql_stmt = truncate_stmt;
      IF debug_mode_in THEN
        SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
      ELSE  
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF;  
    ELSE
      LEAVE truncate_log_table_stmts;
    END IF;
  END LOOP;
  -- ==================================
  CLOSE truncate_log_table_stmts_cur;

  SET @old_fk_checks = (SELECT @@SESSION.FOREIGN_KEY_CHECKS); 
  SET @@SESSION.FOREIGN_KEY_CHECKS = 0;

  OPEN truncate_table_stmts_cur;
  -- ==================================
  truncate_table_stmts:
  LOOP
    SET done = FALSE;
    FETCH truncate_table_stmts_cur
     INTO truncate_stmt; 
    IF NOT done THEN
      SET @sql_stmt = truncate_stmt;
      IF debug_mode_in THEN
        SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF;  
    ELSE
      LEAVE truncate_table_stmts;
    END IF;
  END LOOP;
  -- ==================================
  CLOSE truncate_table_stmts_cur;

  SET error_code_out = 0;

  -- restore FK Checks
  SET @@SESSION.FOREIGN_KEY_CHECKS = @old_fk_checks;
  
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;

END$$

DELIMITER ;

SELECT '====> Procedure ''truncate_unused_tables'' has been created' AS "Info:" FROM dual;

-- ============================================================================

/*
SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
SET @@SESSION.SQL_MODE = '';

SET @DEBUG_MODE = TRUE;

CALL elt.truncate_unused_tables (@err_num, @DEBUG_MODE);

SET @sql_stmt = IF(@err_num <> 0,
                   CONCAT('SELECT "====> Could not truncate tables. Error = ', @err_num, '" AS "Error:" FROM dual'),
                   CONCAT('SELECT "====> Unused tables have been truncated" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
*/

-- ============================================================================

DROP PROCEDURE IF EXISTS elt.truncate_unused_tables;

SELECT '====> Procedure ''truncate_unused_tables'' has been dropped' AS "Info:" FROM dual;

SET @@SESSION.SQL_MODE = @old_sql_mode;
 
 
 