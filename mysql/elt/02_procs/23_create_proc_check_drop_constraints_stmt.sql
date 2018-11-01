/*
  Version:
    2011.12.06.01
  Script:
    23_create_proc_check_drop_constraints_stmt.sql
  Description:
    Display or Execute DROP FOREIGN KEY statements for DB tables in STAGE area.
  Input:
    * debug_mode      - Debug Mode.
                        Values:
                          * TRUE  (1) - show SQL statements
                          * FALSE (0) - execute SQL statements
  Output:
    * error_code: 
      * 0:  Success
      * -2: Error
  Istall:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\23_create_proc_check_drop_constraints_stmt.sql
  Usage:
    CALL elt.check_drop_constraints_stmt (@err, TRUE);  -- display SQL only
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.check_drop_constraints_stmt
$$

CREATE PROCEDURE elt.check_drop_constraints_stmt
(
  OUT error_code_out     INTEGER,
   IN debug_mode_in      BOOLEAN
)
BEGIN

  DECLARE done BOOLEAN DEFAULT FALSE;
  DECLARE stmt VARCHAR(256); 

  -- Drop FK Constarint Statements
  DECLARE drop_fk_contraints_cur CURSOR
  FOR
    SELECT DISTINCT CONCAT('ALTER TABLE ', constraint_schema, '.', table_name, 
                           ' DROP ', constraint_type, ' ', constraint_name
                          ) AS stmt
      FROM information_schema.table_constraints   tcn
        INNER JOIN elt.src_tables                 src
          ON tcn.constraint_schema = src.src_schema_name
    --      AND tcn.table_name     = src.src_table_name   -- for all tables, not migrated only
     WHERE constraint_type = 'FOREIGN KEY'
     ORDER BY constraint_schema, table_name, constraint_name;

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
    
    OPEN drop_fk_contraints_cur;
    -- ================================
    drop_fk_contraints:
    LOOP
      SET done = FALSE;
      FETCH drop_fk_contraints_cur
       INTO stmt;
      -- check end of Loop (FETCH)
      IF NOT done THEN
        SET @sql_stmt = stmt;
        IF debug_mode_in THEN
          SELECT CONCAT(@LF, 
                        CAST(@sql_stmt AS CHAR), ";", 
                        @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF; 
      ELSE
        LEAVE drop_fk_contraints;
      END IF;  -- IF-ELSE NOT done
    END LOOP;
    -- ================================
    CLOSE drop_fk_contraints_cur;
    SET error_code_out = 0;
  END;  -- exec  
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END$$

DELIMITER ;

SELECT 'Procedure ''check_drop_constraints_stmt'' has been created' AS "Info:" FROM dual;
