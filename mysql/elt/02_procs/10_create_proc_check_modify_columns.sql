/*
  Version:
    2011.11.12.01
  Script:
    10_create_proc_check_modify_columns.sql
  Description:
    Compare columns in 2 databases, prepare "ALTER TABLE ..." SQL statements, 
    and apply them in local database against ALL existing ELT schemas.
  Input:
    * host_alias      - SRC Host Alias. Values: [db1|db2]
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
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\10_create_proc_check_modify_columns.sql
  Usage:  
    CALL elt.check_modify_columns (@err, 'db1', 'account', 'account', FALSE);  -- execute
    CALL elt.check_modify_columns (@err, 'db2', 'catalog', 'content_item_external_item_mapping', TRUE);  -- debug
*/
DELIMITER $$ 

DROP PROCEDURE IF EXISTS elt.check_modify_columns$$

CREATE PROCEDURE elt.check_modify_columns
(  
 OUT error_code_out      INTEGER,
  IN host_alias_in       VARCHAR(16),    -- [db1|db2|...]
  IN src_schema_name_in  VARCHAR(64),
  IN src_table_name_in   VARCHAR(64),
  IN debug_mode_in       BOOLEAN
) 
BEGIN

  DECLARE DB1_HOST_ALIAS          VARCHAR(16) DEFAULT 'db1';
  DECLARE DB2_HOST_ALIAS          VARCHAR(16) DEFAULT 'db2';
  
  DECLARE STAGE_SCHEMA_TYPE        VARCHAR(16) DEFAULT 'STAGE';
  DECLARE DELTA_SCHEMA_TYPE        VARCHAR(16) DEFAULT 'DELTA';

  DECLARE STAGE_SCHEMA_NAME        VARCHAR(64) DEFAULT 'db_stage';
  DECLARE DELTA_SCHEMA_NAME        VARCHAR(64) DEFAULT 'db_delta';

  DECLARE MDF_DTM_COL_NAME         VARCHAR(64) DEFAULT "modified_dtm";      -- catalog
  DECLARE LAST_MOD_TIME_COL_NAME   VARCHAR(64) DEFAULT "last_mod_time";     -- loag_catalog
  DECLARE LOG_CRT_DTM_COL_NAME     VARCHAR(64) DEFAULT "log_created_dtm";   -- catalog
  DECLARE LOG_MDF_DTM_COL_NAME     VARCHAR(64) DEFAULT "log_modified_dtm";  -- account   

  DECLARE ACCT_COL_NAME            VARCHAR(64) DEFAULT "account_id";
  DECLARE OWNER_ACCT_COL_NAME      VARCHAR(64) DEFAULT "owner_account_id";
  
  DECLARE v_shard_schema_name      VARCHAR(64);
  DECLARE v_shard_table_name       VARCHAR(64);

  DECLARE v_host_alias             VARCHAR(16);
  DECLARE v_dst_schema_name        VARCHAR(64); 

  DECLARE v_column_stmt            VARCHAR(256);
  DECLARE v_column_name            VARCHAR(64);
  DECLARE v_link_table_name        VARCHAR(64);
  DECLARE is_tbl_modified          BOOLEAN DEFAULT FALSE;

  DECLARE is_stage_sch_exists      BOOLEAN DEFAULT FALSE;  -- 0
  DECLARE is_delta_sch_exists      BOOLEAN DEFAULT FALSE;  -- 0
  DECLARE is_table_exists          BOOLEAN DEFAULT FALSE;  -- 0
   
  DECLARE done                     BOOLEAN DEFAULT FALSE;

  --
  -- Shard Information
  --
  DECLARE shard_info_cur CURSOR
  FOR
    SELECT DISTINCT shard_schema_name,
           shard_table_name
      FROM elt.shard_profiles   spf
     WHERE host_alias = v_host_alias
       AND status     = 1;              -- active shard

  -- DB1 --
  DECLARE db1_column_stmts_cur CURSOR
  FOR 
    SELECT CASE table_location WHEN "Local Table" THEN CONCAT("ALTER TABLE ", v_dst_schema_name, ".", table_name, 
                                                              " DROP COLUMN ", column_name, " ", UPPER(column_type),   -- save full set of attributes to recover the column
                                                              IF (is_nullable = "NO", 
                                                                  " NOT NULL", 
                                                                  " NULL"
                                                                 ),
                                                              IF (column_default IS NOT NULL, 
                                                                  CONCAT(" DEFAULT \'", column_default, "\'"),
                                                                  ""
                                                                 ),
                                                              IF (column_key = "PRI", " PRIMARY KEY", "")
                                                             )
                               ELSE CONCAT("ALTER TABLE ", v_dst_schema_name, ".", table_name, 
                                           " ADD COLUMN ", column_name, " ", UPPER(column_type),
                                           IF (is_nullable = "NO", 
                                               " NOT NULL", 
                                               " NULL"
                                              ),
                                           IF (column_default IS NOT NULL, 
                                               CONCAT(" DEFAULT \'", column_default, "\'"),
                                               ""
                                              ),
                                           IF (column_key = "PRI", " PRIMARY KEY", "")
                                          )
           END AS sql_stmt_columns
      FROM 
       (SELECT MIN(table_location)  AS table_location,
               table_name,
               column_name, 
               column_type,
               is_nullable,
               column_default,
               column_key 
          FROM 
           (SELECT "Local Table"    AS table_location,
                   table_name,
                   column_name, 
                   column_type,
                   is_nullable,
                   column_default,
                   IF(column_key = "MUL", "", column_key) AS column_key,
                   ordinal_position
              FROM information_schema.columns
             WHERE table_schema = v_dst_schema_name      -- [db_stage|db_delta]
               AND table_name   = src_table_name_in
            UNION ALL 
            SELECT "Remote Table"   AS table_location,
                   table_name,
                   column_name, 
                   column_type,
                   is_nullable,
                   CASE WHEN (column_type = "timestamp" AND column_default = "0000-00-00 00:00:00") THEN "2000-01-01 00:00:00"
                        ELSE column_default
                   END              AS column_default,
                   IF(column_key = "MUL", "", column_key) AS column_key,
                   ordinal_position
              FROM elt.db1_information_schema_columns
             WHERE table_schema = src_schema_name_in     -- remote db schema
               AND table_name   = src_table_name_in
           )  q1
       GROUP BY table_name,
                column_name, 
                column_type,
                column_key 
        HAVING COUNT(*) = 1
         ORDER BY table_name, ordinal_position
       )  q2;

  -- DB2 --
  DECLARE db2_column_stmts_cur CURSOR
  FOR 
    SELECT CASE table_location WHEN "Local Table" THEN CONCAT("ALTER TABLE ", v_dst_schema_name, ".", table_name, 
                                                              " DROP COLUMN ", column_name, " ", UPPER(column_type),   -- save full set of attributes to recover the column
                                                              IF (is_nullable = "NO", 
                                                                  " NOT NULL", 
                                                                  " NULL"
                                                                 ),
                                                              IF (column_default IS NOT NULL, 
                                                                  CONCAT(" DEFAULT \'", column_default, "\'"),
                                                                  ""
                                                                 ),
                                                              IF (column_key = "PRI", " PRIMARY KEY", "")
                                                             )
                               ELSE CONCAT("ALTER TABLE ", v_dst_schema_name, ".", table_name, 
                                           " ADD COLUMN ", column_name, " ", UPPER(column_type),
                                           IF (is_nullable = "NO", 
                                               " NOT NULL", 
                                               " NULL"
                                              ),
                                           IF (column_default IS NOT NULL, 
                                               CONCAT(" DEFAULT \'", column_default, "\'"),
                                               ""
                                              ),
                                           IF (column_key = "PRI", " PRIMARY KEY", "")
                                          )
           END AS sql_stmt_columns
      FROM 
       (SELECT MIN(table_location)  AS table_location,
               table_name,
               column_name, 
               column_type,
               is_nullable,
               column_default,
               column_key 
          FROM 
           (SELECT "Local Table"    AS table_location,
                   table_name,
                   column_name, 
                   column_type,
                   is_nullable,
                   column_default,
                   column_key,
                   ordinal_position
              FROM information_schema.columns
             WHERE table_schema = v_dst_schema_name      -- [db_stage|db_delta]
               AND table_name   = src_table_name_in
            UNION ALL 
            SELECT "Remote Table"   AS table_location,
                   table_name,
                   column_name, 
                   column_type,
                   is_nullable,
                   CASE WHEN (column_type = "timestamp" AND column_default = "0000-00-00 00:00:00") THEN "2000-01-01 00:00:00"
                        ELSE column_default
                   END              AS column_default,
                   column_key, 
                   ordinal_position
              FROM elt.db2_information_schema_columns
             WHERE table_schema = src_schema_name_in     -- remote db schema
               AND table_name   = src_table_name_in
           )  q1
--         WHERE q1.column_name NOT IN
--           (SELECT src_column_name
--              FROM elt.ddl_column_changes
--             WHERE host_alias      = DB2_HOST_ALIAS
--               AND src_schema_name = src_schema_name_in
--               AND src_table_name  = src_table_name_in 
--           )
       GROUP BY table_name,
                column_name, 
                column_type,
                column_key 
        HAVING COUNT(*) = 1
         ORDER BY table_name, ordinal_position
       )  q2;

  -- ==================================
  -- Modification stmts 
  -- ==================================
  
  --
  -- STAGE
  --
  DECLARE modify_stage_columns_cur CURSOR
  FOR 
    SELECT CASE WHEN dcc.action = 'ADD' THEN CONCAT('ALTER TABLE ', STAGE_SCHEMA_NAME, '.', dcc.src_table_name, 
                                                    ' ADD COLUMN ', dcc.src_column_name, ' ', UPPER(dcc.column_attributes)
                                                   )
                WHEN dcc.action = 'DROP' THEN CONCAT('ALTER TABLE ', STAGE_SCHEMA_NAME, '.', dcc.src_table_name, 
                                                     ' DROP COLUMN ', dcc.src_column_name
                                                    )
                WHEN dcc.action = 'MODIFY' THEN CONCAT('ALTER TABLE ', STAGE_SCHEMA_NAME, '.', dcc.src_table_name, 
                                                       ' MODIFY COLUMN ', dcc.src_column_name, ' ', UPPER(dcc.column_attributes)
                                                      )
                WHEN dcc.action = 'ALTER' THEN CONCAT('ALTER TABLE ', STAGE_SCHEMA_NAME, '.', dcc.src_table_name, 
                                                      ' ALTER COLUMN ', dcc.src_column_name, ' SET DEFAULT ', UPPER(dcc.column_attributes)
                                                     )
           END       AS modify_stmt
     FROM elt.ddl_column_changes  dcc
    WHERE dcc.elt_schema_type = STAGE_SCHEMA_TYPE
      AND dcc.host_alias      = v_host_alias
      AND dcc.src_schema_name = src_schema_name_in
      AND dcc.src_table_name  = src_table_name_in 
      AND dcc.applied_to_table = 0;
  
  --
  -- DELTA
  --
  DECLARE modify_delta_columns_cur CURSOR
  FOR 
    SELECT CASE WHEN dcc.action = 'ADD' THEN CONCAT('ALTER TABLE ', DELTA_SCHEMA_NAME, '.', dcc.src_table_name, 
                                                    ' ADD COLUMN ', dcc.src_column_name, ' ', UPPER(dcc.column_attributes)
                                                   )
                WHEN dcc.action = 'DROP' THEN CONCAT('ALTER TABLE ', DELTA_SCHEMA_NAME, '.', dcc.src_table_name, 
                                                     ' DROP COLUMN ', dcc.src_column_name
                                                    )
                WHEN dcc.action = 'MODIFY' THEN CONCAT('ALTER TABLE ', DELTA_SCHEMA_NAME, '.', dcc.src_table_name, 
                                                       ' MODIFY COLUMN ', dcc.src_column_name, ' ', UPPER(dcc.column_attributes)
                                                      )
                WHEN dcc.action = 'ALTER' THEN CONCAT('ALTER TABLE ', DELTA_SCHEMA_NAME, '.', dcc.src_table_name, 
                                                      ' ALTER COLUMN ', dcc.src_column_name, ' SET DEFAULT ', UPPER(dcc.column_attributes)
                                                     )
           END       AS modify_stmt
     FROM elt.ddl_column_changes  dcc
    WHERE dcc.elt_schema_type = DELTA_SCHEMA_TYPE
      AND dcc.host_alias      = v_host_alias
      AND dcc.src_schema_name = src_schema_name_in
      AND dcc.src_table_name  = src_table_name_in 
      AND dcc.applied_to_table = 0;

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

    SET error_code_out = -2;
    SET v_host_alias = LOWER(host_alias_in);

    -- 
    IF (src_schema_name_in IS NULL) OR (src_table_name_in IS NULL) THEN
      SELECT CONCAT('Schema [', src_schema_name_in, '] Name OR Table Name [', src_table_name_in, '] is not defined') AS "ERROR" FROM dual;
      SET error_code_out = -3;
      LEAVE exec;
    END IF;

    -- 
    -- Shard Info
    --
--    OPEN shard_info_cur;   -- F(v_host_alias)
--    FETCH shard_info_cur
--     INTO v_shard_schema_name,
--          v_shard_table_name;
--    CLOSE shard_info_cur;
    
--    IF (src_schema_name_in <> v_shard_schema_name) AND 
--       (src_table_name_in <> v_shard_table_name) THEN
    
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
        INTO is_delta_sch_exists
        FROM information_schema.schemata 
       WHERE schema_name = DELTA_SCHEMA_NAME;

      -- ====================================================
      -- STAGE schema: Compare columns 
      --               Modify STAGE tables
      --               Insert into ddl_column_changes
      -- ====================================================
      IF is_stage_sch_exists THEN

        SET v_dst_schema_name = STAGE_SCHEMA_NAME;

        IF (v_host_alias = DB1_HOST_ALIAS) THEN
          OPEN db1_column_stmts_cur;                  -- F(v_dst_schema_name)
        ELSE
          OPEN db2_column_stmts_cur;                  -- F(v_dst_schema_name) 
        END IF;  

        -- ============================
        proc_column_stmts:
        LOOP

          SET done          = FALSE;
          SET v_column_stmt = '';

          IF (v_host_alias = DB1_HOST_ALIAS) THEN
            FETCH db1_column_stmts_cur INTO v_column_stmt;
          ELSE  
            FETCH db2_column_stmts_cur INTO v_column_stmt;
          END IF;

          IF NOT done THEN
            -- Get Column Name
            SET v_column_name = (SELECT RTRIM(SUBSTRING_INDEX(LTRIM(SUBSTRING_INDEX(v_column_stmt, 'COLUMN', -1)), ' ', 1)));
            -- Statement
            SET @sql_stmt = v_column_stmt;
            --
            -- Prepare Requests for modification in ddl_column_changes table
            --
            IF is_stage_sch_exists THEN
              INSERT INTO elt.ddl_column_changes (elt_schema_type, action, host_alias, src_schema_name, src_table_name, src_column_name, column_attributes, created_by, created_at)
              SELECT STAGE_SCHEMA_TYPE,
                     CASE WHEN POSITION('ADD' IN v_column_stmt) > 0 THEN 'ADD'
                          ELSE 'DROP'
                     END                             AS action,
                     v_host_alias                    AS host_alias,
                     src_schema_name_in              AS src_schema_name,
                     src_table_name_in               AS src_table_name, 
                     v_column_name                   AS src_column_name,
                     SUBSTR(LTRIM(SUBSTRING_INDEX(@sql_stmt, 'COLUMN', -1)), 
                            POSITION(' ' IN LTRIM(SUBSTRING_INDEX(@sql_stmt, 'COLUMN', -1))) + 1) AS column_attributes,
                     SUBSTRING_INDEX(USER(), '@', 1) AS created_by,
                     CURRENT_TIMESTAMP()             AS created_at
                FROM dual;
            END IF;

            IF is_delta_sch_exists THEN
              INSERT INTO elt.ddl_column_changes (elt_schema_type, action, host_alias, src_schema_name, src_table_name, src_column_name, column_attributes, created_by, created_at)
              SELECT DELTA_SCHEMA_TYPE,
                     CASE WHEN POSITION('ADD' IN v_column_stmt) > 0 THEN 'ADD'
                          ELSE 'DROP'
                     END                             AS action,
                     v_host_alias                    AS host_alias,
                     src_schema_name_in              AS src_schema_name,
                     src_table_name_in               AS src_table_name, 
                     v_column_name                   AS src_column_name,
                     SUBSTR(LTRIM(SUBSTRING_INDEX(@sql_stmt, 'COLUMN', -1)), 
                            POSITION(' ' IN LTRIM(SUBSTRING_INDEX(@sql_stmt, 'COLUMN', -1))) + 1) AS column_attributes,
                     SUBSTRING_INDEX(USER(), '@', 1) AS created_by,
                     CURRENT_TIMESTAMP()             AS created_at
                FROM dual;
            END IF;

            --
            -- Possible updates of src_tables if we addding a new column 
            --
            IF (LENGTH(@sql_stmt) > 0) AND (POSITION("DROP" IN @sql_stmt) = 0) THEN
              -- ========================
              -- Update DTM Column Name in src_tables
              -- ========================
              IF (v_host_alias = DB1_HOST_ALIAS) THEN
                -- DB1
                IF (v_column_name = MDF_DTM_COL_NAME) OR
                   (v_column_name = LOG_MDF_DTM_COL_NAME) THEN
                   UPDATE elt.src_tables
                     SET dtm_column_name = v_column_name,
                         modified_by     = SUBSTRING_INDEX(USER(), '@', 1),
                         modified_at     = CURRENT_TIMESTAMP()
                   WHERE host_alias      = DB1_HOST_ALIAS
                     AND src_schema_name = src_schema_name_in
                     AND src_table_name  = src_table_name_in;
                END IF;     
              ELSE
                -- DB2
                IF (v_column_name = MDF_DTM_COL_NAME) OR
                   (v_column_name = LOG_CRT_DTM_COL_NAME) OR
                   (v_column_name = LAST_MOD_TIME_COL_NAME) THEN
                   UPDATE elt.src_tables
                     SET dtm_column_name = v_column_name,
                         modified_by     = SUBSTRING_INDEX(USER(), '@', 1),
                         modified_at     = CURRENT_TIMESTAMP()
                   WHERE host_alias      = DB2_HOST_ALIAS
                     AND src_schema_name = src_schema_name_in
                     AND src_table_name  = src_table_name_in;
                END IF;     
              END IF;  -- IF-ELSE (v_host_alias = DB1_HOST_ALIAS)

              -- ========================
              -- Update SHARDING Column Name in src_tables for DB2
              -- ========================
              IF (v_host_alias = DB2_HOST_ALIAS) AND 
                 ((v_column_name = ACCT_COL_NAME) OR
                 (v_column_name = OWNER_ACCT_COL_NAME)) THEN

                UPDATE elt.src_tables
                   SET sharding_column_name = v_column_name,
                       modified_by          = SUBSTRING_INDEX(USER(), '@', 1),
                       modified_at          = CURRENT_TIMESTAMP()
                 WHERE host_alias      = v_host_alias
                   AND src_schema_name = src_schema_name_in
                   AND src_table_name  = src_table_name_in;

              END IF;  -- IF (v_column_name)

              -- ========================
              -- Update PROC_PK Column Name in src_tables
              -- ========================
              IF POSITION('_log' IN src_table_name_in) = 0 THEN
                -- define PK
                IF POSITION('PRIMARY KEY' IN v_column_stmt) > 0 THEN
                  UPDATE elt.src_tables
                     SET proc_pk_column_name = v_column_name,
                         modified_by         = SUBSTRING_INDEX(USER(), '@', 1),
                         modified_at         = CURRENT_TIMESTAMP()
                   WHERE host_alias      = v_host_alias
                     AND src_schema_name = src_schema_name_in
                     AND src_table_name  = src_table_name_in;
                END IF;
              ELSE
                -- define FK to MASTER table
                IF (SUBSTRING_INDEX(v_column_name, '_id', 1) = SUBSTRING_INDEX(src_table_name_in, '_log', 1)) THEN
                  UPDATE elt.src_tables
                     SET proc_pk_column_name = v_column_name,
                         modified_by         = SUBSTRING_INDEX(USER(), '@', 1),
                         modified_at         = CURRENT_TIMESTAMP()
                   WHERE host_alias      = v_host_alias
                     AND src_schema_name = src_schema_name_in
                     AND src_table_name  = src_table_name_in;
                END IF;
              END IF;  -- IF POSITION('_log' IN src_table_name_in)

            END IF;  -- IF LENGTH(@sql_stmt) > 0
          ELSE
            LEAVE proc_column_stmts;
          END IF;

        END LOOP;  -- proc_column_stmts
        -- ============================

        IF (v_host_alias = DB1_HOST_ALIAS) THEN
          CLOSE db1_column_stmts_cur;
        ELSE  
          CLOSE db2_column_stmts_cur;
        END IF;  

      ELSE  
        SET error_code_out = -5;
        LEAVE exec;
      END IF;  -- IF is_stage_sch_exists
      -- ================================

      -- ====================================================
      -- STAGE schema
      -- ====================================================

      SET is_tbl_modified = FALSE;
      OPEN modify_stage_columns_cur;  -- F(v_host_alias, src_schema_name_in, src_table_name_in, applied_to_table = 0)
      -- ================================
      modify_stage_columns:
      LOOP
        SET done          = FALSE;
        SET v_column_stmt = '';
        FETCH modify_stage_columns_cur INTO v_column_stmt;
        IF NOT done THEN 
          IF (LENGTH(v_column_stmt) > 0) THEN
            IF POSITION("DROP" IN v_column_stmt) > 0 THEN
              -- DROP index on column before DROP column
              SET v_column_name = (SELECT RTRIM(SUBSTRING_INDEX(LTRIM(SUBSTRING_INDEX(v_column_stmt, 'COLUMN', -1)), ' ', 1)));
              CALL elt.drop_indexes_on_column (@err_num, STAGE_SCHEMA_TYPE, v_host_alias, src_schema_name_in, src_table_name_in, v_column_name, debug_mode_in);
              --
            END IF;
            -- Drop/Add column
            SET @sql_stmt = v_column_stmt;
            IF debug_mode_in THEN
              SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
            ELSE
              PREPARE query FROM @sql_stmt;
              EXECUTE query;
              DEALLOCATE PREPARE query;
              SET is_tbl_modified = TRUE;
            END IF;  -- IF debug_mode_in 
          END IF;
        ELSE 
          LEAVE modify_stage_columns;
        END IF;
      END LOOP;
      -- ================================
      CLOSE modify_stage_columns_cur;

      IF is_tbl_modified THEN
        -- save info about changes
        UPDATE elt.ddl_column_changes
           SET applied_to_table = 1,
               modified_by      = SUBSTRING_INDEX(USER(), "@", 1),
               modified_at      = CURRENT_TIMESTAMP()
         WHERE elt_schema_type = STAGE_SCHEMA_TYPE
           AND host_alias      = v_host_alias
           AND src_schema_name = src_schema_name_in
           AND src_table_name  = src_table_name_in;
        COMMIT;
        SET is_tbl_modified = FALSE;
      END IF;  

      -- ====================================================
      -- DELTA schema
      -- ====================================================
      IF is_delta_sch_exists THEN

        SET is_tbl_modified = FALSE;
        OPEN modify_delta_columns_cur;  -- F(v_host_alias, src_schema_name_in, src_table_name_in, applied_to_table = 0)
        -- ================================
        modify_delta_columns:
        LOOP
          SET done          = FALSE;
          SET v_column_stmt = '';
          FETCH modify_delta_columns_cur INTO v_column_stmt;
          IF NOT done THEN 
            IF (LENGTH(v_column_stmt) > 0) THEN  -- AND (POSITION("DROP" IN @sql_stmt) = 0) THEN  -- do not DROP column in STAGE (?)
              IF POSITION("DROP" IN v_column_stmt) > 0 THEN
                -- DROP index on column before DROP column
                SET v_column_name = (SELECT RTRIM(SUBSTRING_INDEX(LTRIM(SUBSTRING_INDEX(v_column_stmt, 'COLUMN', -1)), ' ', 1)));
                CALL elt.drop_indexes_on_column (@err_num, DELTA_SCHEMA_TYPE, v_host_alias, src_schema_name_in, src_table_name_in, v_column_name, debug_mode_in);
                --
              END IF;
              -- Drop/Add column
              SET @sql_stmt = v_column_stmt;
              IF debug_mode_in THEN
                SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
              ELSE
                PREPARE query FROM @sql_stmt;
                EXECUTE query;
                DEALLOCATE PREPARE query;
                SET is_tbl_modified = TRUE;
              END IF;  -- IF debug_mode_in 
            END IF;   
          ELSE 
            LEAVE modify_delta_columns;
          END IF;
        END LOOP;
        -- ================================
        CLOSE modify_delta_columns_cur;

        IF is_tbl_modified THEN
          -- save info about changes
          UPDATE elt.ddl_column_changes
             SET applied_to_table = 1,
                 modified_by      = SUBSTRING_INDEX(USER(), "@", 1),
                 modified_at      = CURRENT_TIMESTAMP()
           WHERE elt_schema_type = DELTA_SCHEMA_TYPE
             AND host_alias      = v_host_alias
             AND src_schema_name = src_schema_name_in
             AND src_table_name  = src_table_name_in;
          COMMIT;
          SET is_tbl_modified = FALSE;
        END IF;

      END IF;  -- IF DELTA schema exists  
      -- ================================
--    END IF; -- IF (src_schema_name_in <> v_shard_schema_name) AND (src_table_name_in <> v_shard_table_name) 
    SET error_code_out = 0;
  END;  -- exec
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END$$

DELIMITER ;

SELECT '====> Procedure ''check_modify_columns'' has been created' AS "Info:" FROM dual;
