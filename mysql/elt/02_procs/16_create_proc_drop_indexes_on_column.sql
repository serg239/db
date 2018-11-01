/*
  Version:
    2011.11.12.01
  Script:
    16_create_proc_drop_indexes_on_column.sql
  Description:
    Compare columns in indexes of the STAGE/DELTA table with a given column,
    prepare "ALTER TABLE ... DROP INDEX ..." SQL statements, 
    and apply them in local database against STAGE and DELTA ELT schemas.
  Input:
    * schema_typen    - Schema Type.    Values:  [STAGE|DELTA] 
    * host_alias      - SRC Host Alias. Values:  [db1|db2]
    * src_schema_name - SRC Schema Name.
    * src_table_name  - SRC Table Name.
    * column_name     - Column Name. 
    * debug_mode      - Debug Mode.
                       Values:
                         * FALSE (0) - execute SQL statements
                         * TRUE  (1) - show SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\16_create_proc_drop_indexes_on_column.sql
  Usage:  
    CALL elt.drop_indexes_on_column (@err, 'STAGE', 'db1', 'account', 'account', 'modified_dtm', FALSE);
    CALL elt.drop_indexes_on_column (@err, 'STAGE', 'db2', 'catalog', 'content_item_external_item_mapping', 'external_item_id', FALSE);
    CALL elt.drop_indexes_on_column (@err, 'STAGE', 'db2', 'catalog', 'content_item_external_item_mapping', 'content_item_id', FALSE);
*/
DELIMITER $$ 

DROP PROCEDURE IF EXISTS elt.drop_indexes_on_column$$

CREATE PROCEDURE elt.drop_indexes_on_column
(  
 OUT error_code_out      INTEGER,
  IN schema_type_in      VARCHAR(16),   -- [STAGE|DELTA] 
  IN host_alias_in       VARCHAR(16),   -- [db1|db2]
  IN src_schema_name_in  VARCHAR(64),
  IN src_table_name_in   VARCHAR(64),
  IN column_name_in      VARCHAR(64),
  IN debug_mode_in       BOOLEAN
) 
BEGIN

  DECLARE STAGE_SCHEMA_TYPE     VARCHAR(16) DEFAULT 'STAGE';
  DECLARE DELTA_SCHEMA_TYPE     VARCHAR(16) DEFAULT 'DELTA';

  DECLARE STAGE_SCHEMA_NAME     VARCHAR(64) DEFAULT 'db_stage';
  DECLARE DELTA_SCHEMA_NAME     VARCHAR(64) DEFAULT 'db_delta';

  DECLARE v_dst_schema_name     VARCHAR(64);

  DECLARE v_index_stmt          VARCHAR(256);
  DECLARE v_index_name          VARCHAR(64);
  DECLARE is_idx_modified       BOOLEAN DEFAULT FALSE;

  DECLARE is_table_exists       BOOLEAN DEFAULT FALSE;  -- 0
  DECLARE done                  BOOLEAN DEFAULT FALSE;  -- 0

  DECLARE index_stmts_cur CURSOR
  FOR 
    SELECT CONCAT("ALTER TABLE ", v_dst_schema_name, ".", table_name, 
                  " DROP INDEX ", index_name,
                  IF (LENGTH(uniq) > 0, 
                      CONCAT(" [ ", uniq, " ]"),
                      ""
                     ),
                  " (", columns, ")"  -- save full set of attributes to recover the column
                 )  AS sql_stmt_indexes
      FROM
        (SELECT index_name,
                table_schema,
                table_name,
                uniq,
                columns
           FROM    
            (SELECT index_name,
                    table_schema,
                    table_name,
                    CASE WHEN non_unique = 0 THEN 'UNIQUE' 
                                             ELSE ''
                    END  AS uniq,
                    GROUP_CONCAT(column_name ORDER BY seq_in_index SEPARATOR ', ') AS columns 
               FROM information_schema.statistics
              WHERE table_schema = v_dst_schema_name
                AND table_name   = src_table_name_in
                AND index_name  <> 'PRIMARY'
              GROUP BY index_name, table_schema, table_name, uniq 
            ) q1  
          WHERE POSITION(column_name_in IN columns) > 0
          ORDER BY index_name
        )  q2;

  -- ==================================
  -- Modification stmt
  -- ==================================
  DECLARE modify_indexes_cur CURSOR
  FOR
    SELECT CONCAT('ALTER TABLE ', v_dst_schema_name, '.', src_table_name,
                  ' DROP INDEX ', index_name
                 )  AS modify_stmt
     FROM elt.ddl_index_changes
    WHERE elt_schema_type  = schema_type_in    -- [STAGE|DELTA]
      AND host_alias       = host_alias_in     -- [db1|db2]
      AND src_schema_name  = src_schema_name_in
      AND src_table_name   = src_table_name_in 
      AND applied_to_table = 0;

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
    -- 
    IF (src_schema_name_in IS NULL) OR (src_table_name_in IS NULL) THEN
      SELECT CONCAT('Schema [', src_schema_name_in, '] Name OR Table Name [', src_table_name_in, '] is not defined') AS "ERROR" FROM dual;
      SET error_code_out = -3;
      LEAVE exec;
    END IF;

    -- Define the schema name
    IF schema_type_in = STAGE_SCHEMA_TYPE THEN
      SET v_dst_schema_name = STAGE_SCHEMA_NAME;
    ELSEIF schema_type_in = DELTA_SCHEMA_TYPE THEN
      SET v_dst_schema_name = DELTA_SCHEMA_NAME;
    END IF;

    -- ====================================================
    -- Prepare statements for schema
    -- ====================================================
    SET is_table_exists = FALSE;
    SELECT TRUE 
      INTO is_table_exists
      FROM information_schema.tables
     WHERE table_schema = v_dst_schema_name
       AND table_name   = src_table_name_in;

    -- ================================
    IF is_table_exists THEN
      OPEN index_stmts_cur;                  -- F(schema_type_in, v_dst_schema_name, host_alias_in, src_schema_name_in, src_table_name_in)
      -- ============================
      proc_index_stmts:
      LOOP
        SET done          = FALSE;
        SET v_index_stmt = '';
        FETCH index_stmts_cur INTO v_index_stmt;
        IF NOT done THEN
          -- Statement
          SET @sql_stmt = v_index_stmt;
          --
          -- Save Requests for modification in ddl_index_changes table
          --
          INSERT INTO elt.ddl_index_changes (elt_schema_type, action, host_alias, src_schema_name, src_table_name, index_name, index_type, index_columns, created_by, created_at)
          SELECT schema_type_in,
                 'DROP'                          AS action,
                 host_alias_in                   AS host_alias,
                 src_schema_name_in              AS src_schema_name,
                 src_table_name_in               AS src_table_name, 
                 SUBSTRING_INDEX(LTRIM(SUBSTRING_INDEX(@sql_stmt, 'INDEX', -1)), ' ', 1) AS index_name,
                 IF (POSITION('UNIQUE' IN @sql_stmt) > 0, 'UNIQUE', '')                  AS index_type,
                 SUBSTRING_INDEX(SUBSTRING_INDEX(@sql_stmt, '(', -1), ')', 1)            AS index_columns,
                 SUBSTRING_INDEX(USER(), '@', 1) AS created_by,
                 CURRENT_TIMESTAMP()             AS created_at
            FROM dual;
        ELSE
          LEAVE proc_index_stmts;
        END IF;
      END LOOP;  -- proc_index_stmts
      -- ============================
      CLOSE index_stmts_cur;
    ELSE  
      SET error_code_out = -5;
      LEAVE exec;
    END IF;  -- IF STAGE schema exists

    -- ====================================================
    -- ADD/DROP indexes on table
    -- ====================================================
    SET is_idx_modified = FALSE;

    OPEN modify_indexes_cur;  -- F(schema_type_in, host_alias_in, src_schema_name_in, src_table_name_in, applied_to_stage = 0)
    -- ================================
    modify_indexes:
    LOOP
      SET done            = FALSE;
      SET is_idx_modified = FALSE;

      SET v_index_stmt = '';
      FETCH modify_indexes_cur INTO v_index_stmt;
      SET @sql_stmt = v_index_stmt;

      IF NOT done THEN 
        IF (LENGTH(@sql_stmt) > 0) THEN
          IF debug_mode_in THEN
            SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
          END IF;  -- IF debug_mode_in 
          SET is_idx_modified = TRUE;
        END IF;  
      ELSE 
        LEAVE modify_indexes;
      END IF;
    END LOOP;
    -- ================================
    CLOSE modify_indexes_cur;

    IF is_idx_modified THEN
      SET v_index_name = SUBSTRING_INDEX(LTRIM(SUBSTRING_INDEX(@sql_stmt, 'INDEX', -1)), ' ', 1);
      -- save info about change of all indexes
      UPDATE elt.ddl_index_changes
         SET applied_to_table = 1,
             modified_by      = SUBSTRING_INDEX(USER(), "@", 1),
             modified_at      = CURRENT_TIMESTAMP()
       WHERE elt_schema_type = schema_type_in
         AND host_alias      = host_alias_in
         AND src_schema_name = src_schema_name_in
         AND src_table_name  = src_table_name_in;
--         AND index_name      = v_index_name;  -- all indexes, out of loop
      COMMIT;
    END IF;  
    SET error_code_out = 0;
  END;  -- exec
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;

END$$

DELIMITER ;

SELECT '====> Procedure ''drop_indexes_on_column'' has been created' AS "Info:" FROM dual;
