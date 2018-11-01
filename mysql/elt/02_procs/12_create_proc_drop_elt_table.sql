/*
  Version:
    2011.11.12.01
  Script:
    12_create_proc_drop_elt_table.sql
  Description:
    Drop table in a given ELT schema.
  Input:
    * schema_type       - Schema Type. 
                          Values: 
                            * LINK  - Link (Federated Tables)
                            * DELTA - Static Tables
                            * STAGE - Static Tables
                            * NULL  - Local Schema (DDL)
    * host_alias        - DB Host Alias.  
                          Values: [db1|db2]
    * src_schema_name   - SRC schema name (same as in src_tables table)
    * src_table_name    - SRC table name (same as in src_tables table)
    * debug_mode        - Debug Mode.
                          Values:
                            * TRUE  (1) - show SQL statements
                            * FALSE (0) - execute SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\12_create_proc_drop_elt_table.sql
  Usage:
    CALL elt.drop_elt_table (@err, 'LINK',  'db2', '01', 'catalog', 'content_item_external_item_mapping', FALSE);   -- db_link
    CALL elt.drop_elt_table (@err, 'DELTA', 'db2', '01', 'catalog', 'content_item_external_item_mapping', FALSE);   -- db_delta   
    CALL elt.drop_elt_table (@err, 'STAGE', 'db2', '01', 'catalog', 'content_item_external_item_mapping', FALSE);   -- db_stage
  Notes:
    
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.drop_elt_table
$$

CREATE PROCEDURE elt.drop_elt_table
(
  OUT error_code_out      INTEGER,
   IN schema_type_in      VARCHAR(16),      -- [LINK|STAGE|DELTA|NULL]
   IN host_alias_in       VARCHAR(16),      -- [db1|db2]
   IN shard_number_in     VARCHAR(2),       -- [01|02|...]  
   IN src_schema_name_in  VARCHAR(64),
   IN src_table_name_in   VARCHAR(64),  
   IN debug_mode_in       BOOLEAN
)
BEGIN

  DECLARE LINK_SCHEMA_TYPE       VARCHAR(8)  DEFAULT 'LINK';        -- link schema type
  DECLARE STAGE_SCHEMA_TYPE      VARCHAR(8)  DEFAULT 'STAGE';       -- stage schema type
  DECLARE DELTA_SCHEMA_TYPE      VARCHAR(8)  DEFAULT 'DELTA';       -- delta schema type
  
  DECLARE LINK_SCHEMA_NAME       VARCHAR(64)  DEFAULT 'db_link';    -- link schema type
  DECLARE STAGE_SCHEMA_NAME      VARCHAR(64)  DEFAULT 'db_stage';   -- stage schema type
  DECLARE DELTA_SCHEMA_NAME      VARCHAR(64)  DEFAULT 'db_delta';   -- delta schema type

  DECLARE v_schema_type          VARCHAR(16) DEFAULT schema_type_in;
  DECLARE v_host_alias           VARCHAR(16) DEFAULT host_alias_in;     -- [db1|db2]
  DECLARE v_shard_number         VARCHAR(2)  DEFAULT shard_number_in;   -- [01|02|...]  
  DECLARE v_src_schema_name      VARCHAR(64) DEFAULT src_schema_name_in;
  DECLARE v_src_table_name       VARCHAR(64) DEFAULT src_table_name_in;

  DECLARE v_schema_name          VARCHAR(64);   -- LINK Schema name from src_tables table 
  DECLARE is_table_exists        BOOLEAN DEFAULT FALSE;
  
  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF = CHAR(10); 

  exec:
  BEGIN

    SET error_code_out = -2;

    SET @sql_stmt = NULL;
    SET is_table_exists = FALSE;

    IF (v_schema_type IS NULL) THEN
      SET v_schema_name = v_src_schema_name;
      SELECT TRUE
        INTO is_table_exists
        FROM information_schema.tables
       WHERE table_schema = v_schema_name
         AND table_name   = v_src_table_name;
      IF is_table_exists THEN
        SET @sql_stmt = CONCAT('DROP TABLE ', v_schema_name, '.', v_src_table_name);
      END IF;
    ELSEIF (v_schema_type = LINK_SCHEMA_TYPE) THEN
      SET v_schema_name = LINK_SCHEMA_NAME;
      SELECT TRUE
        INTO is_table_exists
        FROM information_schema.tables
       WHERE table_schema = v_schema_name
         AND table_name   = CONCAT(v_host_alias, '_', v_shard_number, '_', v_src_schema_name, '_', v_src_table_name);
      IF is_table_exists THEN
        SET @sql_stmt = CONCAT('DROP TABLE ', v_schema_name, '.', v_host_alias, '_', v_shard_number, '_', v_src_schema_name, '_', v_src_table_name); 
      END IF;  
    ELSEIF (v_schema_type = DELTA_SCHEMA_TYPE) THEN
      SET v_schema_name = DELTA_SCHEMA_NAME;
      SELECT TRUE
        INTO is_table_exists
        FROM information_schema.tables
       WHERE table_schema = v_schema_name
         AND table_name   = v_src_table_name;
      IF is_table_exists THEN
        SET @sql_stmt = CONCAT('DROP TABLE ', v_schema_name, '.', v_src_table_name);
      END IF;  
    ELSEIF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
      SET v_schema_name = STAGE_SCHEMA_NAME;
      SELECT TRUE
        INTO is_table_exists
        FROM information_schema.tables
       WHERE table_schema = v_schema_name
         AND table_name   = v_src_table_name;
      IF is_table_exists THEN
        SET @sql_stmt = CONCAT('DROP TABLE ', v_schema_name, '.', v_src_table_name);
      END IF;  
    END IF;  

    -- ==============================
    -- Prepare SQL stmt to DROP TABLE
    -- ==============================
    IF is_table_exists AND (@sql_stmt IS NOT NULL) THEN
      IF debug_mode_in THEN
        SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF;
    END IF;  
    SET error_code_out = 0;
  END; -- exec  
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END
$$

DELIMITER ;

SELECT '====> Procedure ''drop_elt_table'' has been created' AS "Info:" FROM dual;
