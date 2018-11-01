/*
  Version:
    2011.11.12.01
  Script:
    13_create_proc_drop_tmp_tables.sql
  Description:
    Drop tempory tables in a given schema.
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\13_create_proc_drop_tmp_tables.sql
  Usage:
    CALL elt.drop_tmp_tables (@err_num, 'elt');
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.drop_tmp_tables$$

CREATE PROCEDURE elt.drop_tmp_tables
( 
 OUT error_code_out  INTEGER,
  IN schema_name_in  VARCHAR(16)
)
BEGIN

  DECLARE TMP_TABLE_FILTER  VARCHAR(16) DEFAULT 'tmp_%';
  DECLARE v_table_name      VARCHAR(64); 
  
  DECLARE done              BOOLEAN DEFAULT FALSE;
  
  DECLARE tmp_tables_cur CURSOR
  FOR
  SELECT table_name
    FROM information_schema.tables
   WHERE table_schema  = schema_name_in
     AND table_name LIKE TMP_TABLE_FILTER;

  -- Handler
  DECLARE CONTINUE HANDLER
  FOR NOT FOUND
  SET done = TRUE;
  
  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  exec_loop:
  BEGIN
    OPEN tmp_tables_cur;
    SET error_code_out = -2;
    -- ================================
    -- For All TMP Tables
    -- ================================
    tmp_tables_loop:
    LOOP
      SET done = FALSE;
      FETCH tmp_tables_cur
        INTO v_table_name;
      IF done THEN
        LEAVE tmp_tables_loop;
      ELSE
        SET @drop_query = '';
        SELECT CONCAT('DROP TABLE IF EXISTS ', table_schema, '.', table_name) INTO @drop_query
          FROM information_schema.tables
         WHERE table_schema = schema_name_in
           AND table_name = v_table_name;
        IF LENGTH(@drop_query > 0) THEN
          PREPARE query FROM @drop_query;
          EXECUTE query;                  --  USING @ELT_SCHEMA_NAME, @TBL_FILTER;
          DEALLOCATE PREPARE query; 
        END IF;
      END IF;
    END LOOP;
    CLOSE tmp_tables_cur;
    SET error_code_out = 0;
  END;  -- exec_loop:
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END$$

DELIMITER ;

SELECT '====> Procedure ''drop_tmp_tables'' has been created' AS "Info:" FROM dual;
