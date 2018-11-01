/*
  Version:
    2011.11.12.01
  Script:
    14_create_proc_check_modify_indexes.sql
  Description:
    Compare columns in indexes of the STAGE/DELTA table and LINK table,
    prepare "ALTER TABLE ..." SQL statements, 
    and apply them in local database against ALL existing ELT schemas.
  Input:
    * host_alias      - SRC Host Alias. Values:  [db1|db2]
    * src_schema_name - SRC Schema Name.
    * src_table_name  - SRC Table Name.
    * debug_mode      - Debug Mode.
                       Values:
                         * FALSE (0) - execute SQL statements
                         * TRUE  (1) - show SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\14_create_proc_check_modify_indexes.sql
  Usage:  
    CALL elt.check_modify_indexes (@err, 'db1', 'account', 'account', FALSE);  -- execute
    CALL elt.check_modify_indexes (@err, 'db2', 'catalog', 'content_item_external_item_mapping', TRUE);  -- debug
  Notes:
    +---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    | sql_stmt_indexes                                                                                                                                                                                        |
    +---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    | ALTER TABLE db_stage.content_item_external_item_mapping DROP INDEX content_item$content_item_id_account_id_disabled_dtm_status_uidx [ UNIQUE ] (content_item_id, status)                                |
    | ALTER TABLE db_link.db2_01_catalog_content_item_external_item_mapping ADD UNIQUE INDEX c$content_item_id_external_account_id_derived_status_uidx (content_item_id, external_account_id, derived_status) |
    +---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
*/
DELIMITER $$ 

DROP PROCEDURE IF EXISTS elt.check_modify_indexes$$

CREATE PROCEDURE elt.check_modify_indexes
(  
 OUT error_code_out      INTEGER,
  IN host_alias_in       VARCHAR(16),
  IN src_schema_name_in  VARCHAR(64),
  IN src_table_name_in   VARCHAR(64),
  IN debug_mode_in       BOOLEAN
) 
BEGIN

  DECLARE STAGE_SCHEMA_TYPE      VARCHAR(16) DEFAULT 'STAGE';
  DECLARE DELTA_SCHEMA_TYPE      VARCHAR(16) DEFAULT 'DELTA';

  DECLARE LINK_SCHEMA_NAME      VARCHAR(64) DEFAULT 'db_link';
  DECLARE STAGE_SCHEMA_NAME     VARCHAR(64) DEFAULT 'db_stage';
  DECLARE DELTA_SCHEMA_NAME     VARCHAR(64) DEFAULT 'db_delta';

  DECLARE v_dst_schema_name     VARCHAR(64); 

  DECLARE v_index_stmt          VARCHAR(256);
  DECLARE v_index_name          VARCHAR(64);
  DECLARE is_idx_modified       BOOLEAN DEFAULT FALSE;

  DECLARE is_stage_sch_exists   BOOLEAN DEFAULT FALSE;  -- 0
  DECLARE is_delta_sch_exists   BOOLEAN DEFAULT FALSE;  -- 0
  DECLARE is_table_exists       BOOLEAN DEFAULT FALSE;  -- 0

  DECLARE done                  BOOLEAN DEFAULT FALSE;  -- 0

  -- Compare Indexes on table in DST schema and LINK (shard 01) schema
  DECLARE index_stmts_cur CURSOR
  FOR 
    SELECT CASE table_location WHEN "Local Table" THEN CONCAT("ALTER TABLE ", v_dst_schema_name, ".", table_name, 
                                                              " DROP INDEX ", index_name,
                                                              IF (LENGTH(uniq) > 0, 
                                                                  CONCAT(" [ ", uniq, " ]"),
                                                                  ""
                                                                 ),
                                                              " (", columns, ")"  -- save full set of attributes to recover the column
                                                             )
                               ELSE CONCAT("ALTER TABLE ", v_dst_schema_name, ".", src_table_name_in,            -- replace table name
                                           " ADD ", uniq, " INDEX ",
                                           REPLACE
                                             (REPLACE
                                               (REPLACE(index_name, 
                                                        CONCAT(host_alias_in, "_"), ""
                                                       ),
                                                "01_", ""
                                               ), 
                                               CONCAT(src_schema_name_in, "_"), ""
                                             ),
                                           " (", columns, ")"
                                          )
           END AS sql_stmt_indexes
      FROM
       (SELECT MIN(table_location)  AS table_location,
               index_name,
               table_schema,
               table_name,
               uniq,
               columns 
          FROM
            (SELECT "Local Table"    AS table_location,
                     index_name,
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
              UNION ALL
              SELECT "Remote Table"    AS table_location,
                     index_name,
                     table_schema,
                     table_name,
                     CASE WHEN non_unique = 0 THEN 'UNIQUE' 
                                              ELSE ''
                     END  AS uniq,
                     GROUP_CONCAT(column_name ORDER BY seq_in_index SEPARATOR ', ') AS columns 
                FROM information_schema.statistics
               WHERE table_schema = LINK_SCHEMA_NAME
                 AND table_name   = CONCAT(host_alias_in, '_01_', src_schema_name_in, '_', src_table_name_in)
                 AND index_name  <> 'PRIMARY'
               GROUP BY index_name, table_schema, table_name, uniq 
            ) q1
        GROUP BY columns
        HAVING COUNT(*) = 1
        ORDER BY index_name
      ) q2    
    ;

  -- ======================================================
  -- Modification stmts 
  -- ======================================================
  -- ==================================
  -- STAGE
  -- ==================================
  DECLARE modify_stage_indexes_cur CURSOR
  FOR 
    SELECT CASE WHEN dic.action = 'ADD' THEN CONCAT('ALTER TABLE ', STAGE_SCHEMA_NAME, '.', dic.src_table_name, 
                                                    ' ADD ', dic.index_type, ' INDEX ', dic.index_name, ' (', dic.index_columns, ')'
                                                   )
                WHEN dic.action = 'DROP' THEN CONCAT('ALTER TABLE ', STAGE_SCHEMA_NAME, '.', dic.src_table_name, 
                                                     ' DROP INDEX ', dic.index_name
                                                    )
           END       AS modify_stmt
     FROM elt.ddl_index_changes  dic
    WHERE dic.elt_schema_type = STAGE_SCHEMA_TYPE
      AND dic.host_alias      = host_alias_in
      AND dic.src_schema_name = src_schema_name_in
      AND dic.src_table_name  = src_table_name_in 
      AND dic.applied_to_table = 0;
  -- ==================================
  -- DELTA
  -- ==================================
  DECLARE modify_delta_indexes_cur CURSOR
  FOR 
    SELECT CASE WHEN dic.action = 'ADD' THEN CONCAT('ALTER TABLE ', DELTA_SCHEMA_NAME, '.', dic.src_table_name,
                                                    ' ADD ', dic.index_type, ' INDEX ', dic.index_name, ' (', dic.index_columns, ')'
                                                   )
                WHEN dic.action = 'DROP' THEN CONCAT('ALTER TABLE ', DELTA_SCHEMA_NAME, '.', dic.src_table_name, 
                                                     ' DROP INDEX ', dic.index_name
                                                    )
           END       AS modify_stmt
     FROM elt.ddl_index_changes  dic
    WHERE dic.elt_schema_type = DELTA_SCHEMA_TYPE
      AND dic.host_alias      = host_alias_in
      AND dic.src_schema_name = src_schema_name_in
      AND dic.src_table_name  = src_table_name_in 
      AND dic.applied_to_table = 0;

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
    --
    -- Define the environment
    --
    SET is_stage_sch_exists = FALSE;
    SELECT TRUE 
      INTO is_stage_sch_exists
      FROM information_schema.schemata 
     WHERE schema_name = STAGE_SCHEMA_NAME;

    SET is_delta_sch_exists = FALSE;
    SELECT TRUE 
      INTO is_stage_sch_exists
      FROM information_schema.schemata 
     WHERE schema_name = DELTA_SCHEMA_NAME;

    -- ====================================================
    -- Prepare statements for STAGE schema
    -- ====================================================
    IF is_stage_sch_exists THEN
    
      SET v_dst_schema_name = STAGE_SCHEMA_NAME;
     
      OPEN index_stmts_cur;                  -- F(v_dst_schema_name, host_alias_in, src_schema_name_in, src_table_name_in)
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
          -- STAGE
          IF is_stage_sch_exists THEN
            INSERT INTO elt.ddl_index_changes (elt_schema_type, action, host_alias, src_schema_name, src_table_name, index_name, index_type, index_columns, created_by, created_at)
            SELECT STAGE_SCHEMA_TYPE,
                   CASE WHEN POSITION('ADD'  IN @sql_stmt) > 0 THEN 'ADD'
                        WHEN POSITION('DROP' IN @sql_stmt) > 0 THEN 'DROP'
                        ELSE 'N/A'
                   END                             AS action,
                   host_alias_in                   AS host_alias,
                   src_schema_name_in              AS src_schema_name,
                   src_table_name_in               AS src_table_name, 
                   SUBSTRING_INDEX(LTRIM(SUBSTRING_INDEX(@sql_stmt, 'INDEX', -1)), ' ', 1) AS index_name,
                   IF (POSITION('UNIQUE' IN @sql_stmt) > 0, 'UNIQUE', '')                  AS index_type,
                   SUBSTRING_INDEX(SUBSTRING_INDEX(@sql_stmt, '(', -1), ')', 1)            AS index_columns,
                   SUBSTRING_INDEX(USER(), '@', 1) AS created_by,
                   CURRENT_TIMESTAMP()             AS created_at
              FROM dual;
          END IF;
          -- DELTA
          IF is_delta_sch_exists THEN
            INSERT INTO elt.ddl_index_changes (elt_schema_type, action, host_alias, src_schema_name, src_table_name, index_name, index_type, index_columns, created_by, created_at)
            SELECT DELTA_SCHEMA_TYPE,
                   CASE WHEN POSITION('ADD'  IN @sql_stmt) > 0 THEN 'ADD'
                        WHEN POSITION('DROP' IN @sql_stmt) > 0 THEN 'DROP'
                        ELSE 'N/A'
                   END                             AS action,
                   host_alias_in                   AS host_alias,
                   src_schema_name_in              AS src_schema_name,
                   src_table_name_in               AS src_table_name, 
                   SUBSTRING_INDEX(LTRIM(SUBSTRING_INDEX(@sql_stmt, 'INDEX', -1)), ' ', 1) AS index_name,
                   IF (POSITION('UNIQUE' IN @sql_stmt) > 0, 'UNIQUE', '')                  AS index_type,
                   SUBSTRING_INDEX(SUBSTRING_INDEX(@sql_stmt, '(', -1), ')', 1)            AS index_columns,
                   SUBSTRING_INDEX(USER(), '@', 1) AS created_by,
                   CURRENT_TIMESTAMP()             AS created_at
              FROM dual;
          END IF;
        ELSE
          LEAVE proc_index_stmts;
        END IF;
      END LOOP;  -- proc_index_stmts
      -- ============================
      CLOSE index_stmts_cur;
    ELSE  
      SET error_code_out = -5;
      LEAVE exec;
    END IF;  -- IF is_stage_sch_exists

    -- ====================================================
    -- Modify Indexes on table in STAGE schema
    -- ====================================================
    SET is_table_exists = FALSE;
    SELECT TRUE
      INTO is_table_exists
      FROM information_schema.tables 
     WHERE table_schema = STAGE_SCHEMA_NAME
       AND table_name   = src_table_name_in;

    -- ================================
    IF is_table_exists THEN
      SET is_idx_modified = FALSE;
      OPEN modify_stage_indexes_cur;  -- F(host_alias_in, src_schema_name_in, src_table_name_in, applied_to_stage = 0)
      -- ================================
      modify_stage_indexes:
      LOOP
        SET done            = FALSE;
        SET v_index_stmt    = '';
        FETCH modify_stage_indexes_cur INTO v_index_stmt;
        SET @sql_stmt = v_index_stmt;
        IF NOT done THEN 
          IF (LENGTH(@sql_stmt) > 0) THEN
            -- Add/Drop Index on table in STAGE schema
            IF debug_mode_in THEN
              SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
            ELSE
              PREPARE query FROM @sql_stmt;
              EXECUTE query;
              DEALLOCATE PREPARE query;
              SET is_idx_modified = TRUE;
            END IF;  -- IF debug_mode_in 
          END IF;  
        ELSE 
          LEAVE modify_stage_indexes;
        END IF;
      END LOOP;
      -- ================================
      CLOSE modify_stage_indexes_cur;
      -- 
      IF is_idx_modified THEN
        -- SET v_index_name = SUBSTRING_INDEX(LTRIM(SUBSTRING_INDEX(@sql_stmt, 'INDEX', -1)), ' ', 1);
        -- save info
        UPDATE elt.ddl_index_changes
           SET applied_to_table = 1,
               modified_by      = SUBSTRING_INDEX(USER(), "@", 1),
               modified_at      = CURRENT_TIMESTAMP()
         WHERE elt_schema_type = STAGE_SCHEMA_TYPE
           AND host_alias      = host_alias_in
           AND src_schema_name = src_schema_name_in
           AND src_table_name  = src_table_name_in;
           -- AND index_name      = v_index_name;
        COMMIT;
      END IF;  

    END IF;  -- IF table in STAGE schema exists

    -- ====================================================
    -- -- Modify Indexes on table in DELTA schema
    -- ====================================================
    SET is_table_exists = FALSE;
    SELECT TRUE
      INTO is_table_exists
      FROM information_schema.tables 
     WHERE table_schema = DELTA_SCHEMA_NAME
       AND table_name   = src_table_name_in;
    -- ================================
    IF is_table_exists THEN

      SET is_idx_modified = FALSE;
      OPEN modify_delta_indexes_cur;  -- F(host_alias_in, src_schema_name_in, src_table_name_in, applied_to_delta = 0)
      -- ================================
      modify_delta_indexes:
      LOOP
        SET done            = FALSE;
        SET v_index_stmt    = '';
        FETCH modify_delta_indexes_cur INTO v_index_stmt;
        SET @sql_stmt = v_index_stmt;
        IF NOT done THEN 
          IF (LENGTH(@sql_stmt) > 0) THEN
            -- Add/Drop Index on table in DELTA schema
            IF debug_mode_in THEN
              SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
            ELSE
              PREPARE query FROM @sql_stmt;
              EXECUTE query;
              DEALLOCATE PREPARE query;
              SET is_idx_modified = TRUE;
            END IF;  -- IF debug_mode_in 
          END IF;
        ELSE 
          LEAVE modify_delta_indexes;
        END IF;
      END LOOP;
      -- ================================
      CLOSE modify_delta_indexes_cur;

      IF is_idx_modified THEN
        -- SET v_index_name = SUBSTRING_INDEX(LTRIM(SUBSTRING_INDEX(@sql_stmt, 'INDEX', -1)), ' ', 1);
        -- save info
        UPDATE elt.ddl_index_changes
           SET applied_to_table  = 1,
               modified_by       = SUBSTRING_INDEX(USER(), "@", 1),
               modified_at       = CURRENT_TIMESTAMP()
         WHERE elt_schema_type = DELTA_SCHEMA_TYPE
           AND host_alias      = host_alias_in
           AND src_schema_name = src_schema_name_in
           AND src_table_name  = src_table_name_in;
           -- AND index_name      = v_index_name;
        COMMIT;
      END IF;
    END IF;  -- IF table in DELTA schema exists
    -- ================================
    SET error_code_out = 0;
  END;  -- exec
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END$$

DELIMITER ;

SELECT '====> Procedure ''check_modify_indexes'' has been created' AS "Info:" FROM dual;
