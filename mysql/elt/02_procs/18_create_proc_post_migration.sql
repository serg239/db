/*
  Version:
    2011.11.12.01
  Script:
    18_create_proc_post_migration.sql
  Description:
    1. Drop (if empty)/Create DB Schemas.
    2. Drop/Create DB Tables which are not defined in src_tables table.
    3. Move Migrated tables to DB Schemas.
  Input:
    * debug_mode        - Debug Mode.
                          Values:
                            * TRUE  (1) - show SQL statements
                            * FALSE (0) - execute SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\18_create_proc_post_migration.sql
  Usage:
    CALL elt.post_migration (@err, FALSE);
  Notes:
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.post_migration
$$

CREATE PROCEDURE elt.post_migration
(
  OUT error_code_out  INTEGER,
   IN debug_mode_in   BOOLEAN
)
BEGIN

  DECLARE DELTA_SCHEMA_TYPE  VARCHAR(16) DEFAULT 'DELTA';  

  DECLARE STAGE_SCHEMA_NAME  VARCHAR(64) DEFAULT 'db_stage';
  DECLARE DB_ENGINE_TYPE     VARCHAR(64) DEFAULT 'InnoDB';
  
  DECLARE v_host_alias       VARCHAR(16);      -- [db1|db2]
  DECLARE v_shard_number     VARCHAR(2);       -- [01|02|...]  
  DECLARE v_src_schema_name  VARCHAR(64);
  DECLARE v_src_table_name   VARCHAR(64);  

  DECLARE is_sch_exists      BOOLEAN DEFAULT FALSE;
  DECLARE is_table_exists    BOOLEAN DEFAULT FALSE;
  DECLARE done               BOOLEAN DEFAULT FALSE;
  
  --
  -- DB Schemas
  --
  DECLARE db_schemas_cur CURSOR
  FOR
    SELECT DISTINCT isc.table_schema
      FROM elt.db1_information_schema_columns  isc
        INNER JOIN elt.src_tables              st
          ON st.src_schema_name = isc.table_schema
            AND st.host_alias = 'db1'
            AND st.src_table_load_status = 1
    UNION ALL
    SELECT DISTINCT isc.table_schema
      FROM elt.db2_information_schema_columns  isc
        INNER JOIN elt.src_tables              st
          ON st.src_schema_name = isc.table_schema
            AND st.host_alias = 'db2'
            AND st.src_table_load_status = 1
      ORDER BY table_schema;

  --
  -- DB Tables
  --
  DECLARE db_tables_cur CURSOR
  FOR
    SELECT DISTINCT st.host_alias,
                    st.shard_number,
                    isc.table_schema,
                    isc.table_name
      FROM elt.db1_information_schema_columns  isc
        INNER JOIN elt.src_tables              st
          ON st.src_schema_name = isc.table_schema
            AND st.host_alias = 'db1'
     WHERE isc.table_name NOT IN
        (SELECT src_table_name
           FROM elt.src_tables
          WHERE host_alias = 'db1'
            AND src_table_load_status = 1
        )
      AND isc.table_name NOT LIKE 'tmp_%'
--      AND POSITION('$' IN isc.table_name) = 0
    UNION ALL
    SELECT DISTINCT st.host_alias,
                    st.shard_number,
                    isc.table_schema,
                    isc.table_name
      FROM elt.db2_information_schema_columns  isc
        INNER JOIN elt.src_tables              st
          ON st.src_schema_name = isc.table_schema
            AND st.host_alias = 'db2'
     WHERE isc.table_name NOT IN
        (SELECT src_table_name
           FROM elt.src_tables
          WHERE host_alias = 'db2'
            AND src_table_load_status = 1
        )
      AND isc.table_name NOT LIKE 'tmp_%' 
--      AND POSITION('$' IN isc.table_name) = 0
    ORDER BY host_alias, shard_number, table_schema, table_name;

  --
  -- Moved Tables
  -- Select all migrated tables (without shard table)
  --
  DECLARE moved_tables_cur CURSOR
  FOR
    SELECT DISTINCT st.src_schema_name,
                    st.src_table_name
      FROM elt.db1_information_schema_columns  isc
        INNER JOIN elt.src_tables              st
          ON st.src_schema_name = isc.table_schema
            AND st.src_table_name = isc.table_name
            AND st.host_alias = 'db1'
        LEFT OUTER JOIN elt.shard_profiles          spf
          ON st.shard_profile_id = spf.shard_profile_id
            AND spf.status = 1
    WHERE st.src_table_name <> IFNULL(spf.shard_table_name, '')
    UNION ALL
    SELECT DISTINCT st.src_schema_name,
                    st.src_table_name
      FROM elt.db2_information_schema_columns  isc
        INNER JOIN elt.src_tables              st
          ON st.src_schema_name = isc.table_schema
            AND st.src_table_name = isc.table_name
            AND st.host_alias = 'db2'
        LEFT OUTER JOIN elt.shard_profiles          spf
          ON st.shard_profile_id = spf.shard_profile_id
            AND spf.status = 1
     WHERE st.src_table_name <> IFNULL(spf.shard_table_name, '')
     ORDER BY src_schema_name, src_table_name;

  -- 'NOT FOUND' Handler
  DECLARE CONTINUE HANDLER 
  FOR NOT FOUND 
  SET done = TRUE;
  
  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF       = CHAR(10); 
  SET @sql_stmt = '';

  exec:
  BEGIN

    SET error_code_out = -2;

    -- ==================================
    -- 1. Drop/Create DB Schemas
    -- ==================================
    OPEN db_schemas_cur;
    -- ==================================
    db_schemas:
    LOOP
      SET done = FALSE;
      FETCH db_schemas_cur
       INTO v_src_schema_name;         -- Schema Name for Local Schemas (DDL)

      IF NOT done THEN
        SET is_sch_exists = FALSE;
        SELECT TRUE
          INTO is_sch_exists
          FROM information_schema.schemata 
         WHERE schema_name = v_src_schema_name;
        IF is_sch_exists THEN 
          -- ==============================
          -- DROP SCHEMA
          -- ==============================
          SET @sql_stmt = CONCAT('DROP SCHEMA ', v_src_schema_name); 
          IF debug_mode_in THEN
            SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
            COMMIT;
          END IF;
        END IF;  -- IF is_sch_exists
        -- ==============================
        -- CREATE SCHEMA
        -- ==============================
        SET @sql_stmt = CONCAT('CREATE SCHEMA ', v_src_schema_name, ' DEFAULT CHARACTER SET utf8 COLLATE utf8_bin'); 
        IF debug_mode_in THEN
          SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
          COMMIT;
        END IF;
      ELSE
        LEAVE db_schemas;
      END IF;
      SET error_code_out = 0;
    END LOOP;  -- for all DB schemas
    -- ================================
    CLOSE db_schemas_cur;

    -- ==================================
    -- 2. Drop/Create DB Tables (which are not in src_tables)
    -- ==================================
    OPEN db_tables_cur;
    -- ==================================
    db_tables:
    LOOP
      SET done = FALSE;
      FETCH db_tables_cur
       INTO v_host_alias,
            v_shard_number,
            v_src_schema_name,   -- Schema Name for Dummy Tables (DDL only)
            v_src_table_name;         
      IF NOT done THEN
        -- ==============================
        -- DROP TABLE
        -- ==============================
        -- schema_type_in IS NULL
        -- CALL elt.drop_elt_table (@err, NULL,  v_host_alias, v_shard_number, v_src_schema_name, v_src_table_name, debug_mode_in);
        -- ==============================
        -- CREATE TABLE
        -- ==============================
        -- schema_type_in IS NULL
        CALL elt.add_elt_table (@err_num, NULL,  v_host_alias, v_src_schema_name, v_src_table_name, DB_ENGINE_TYPE, debug_mode_in);
        IF (@err_num <> 0) THEN
          SELECT CONCAT('Procedure \'add_elt_table\', ERROR: ', @err_num) AS "ERROR";
        END IF;
      ELSE
        LEAVE db_tables;
      END IF;
      SET error_code_out = 0;
    END LOOP;
    -- ================================
    CLOSE db_tables_cur;
    
    -- ==================================
    -- 3. Move Migrated Tables from DB_STAGE to DB schemas
    -- ==================================
    OPEN moved_tables_cur;
    -- ==================================
    moved_tables:
    LOOP
      SET done = FALSE;
      FETCH moved_tables_cur
       INTO v_src_schema_name,
            v_src_table_name;         
      IF NOT done THEN
        SET is_table_exists = FALSE;
        SELECT TRUE
          INTO is_table_exists
          FROM information_schema.tables
         WHERE table_schema = v_src_schema_name
           AND table_name   = v_src_table_name;
        IF NOT is_table_exists THEN
          -- including shard_schema_name.shard_table_name
          SET @sql_stmt = CONCAT('RENAME TABLE ', STAGE_SCHEMA_NAME, '.', v_src_table_name, @LF,
                                 ' TO ', v_src_schema_name, '.', v_src_table_name);
          IF debug_mode_in THEN
            SELECT CONCAT(@LF, 
                          CAST(@sql_stmt AS CHAR), @LF, 
                          ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
            COMMIT;
          END IF; 
        END IF;  -- IF NOT is_table_exists
      ELSE
        LEAVE moved_tables;
      END IF;
      SET error_code_out = 0;
    END LOOP;
    -- ================================
    CLOSE moved_tables_cur;
    -- ==================================
    -- 4. Close the gap in migrated data before job(s) started 
    --    Get DELTA and append to DB tables
    -- ==================================
    CALL elt.get_elt_data (@err_num, DELTA_SCHEMA_TYPE, FALSE, debug_mode_in);
    -- ==================================
    IF (@err_num <> 0) THEN
      SELECT CONCAT('Procedure \'get_elt_data\', ERROR: ', @err_num) AS "ERROR";
    ELSE  
      SET error_code_out = 0;
    END IF;

    -- ==============================
    -- 5. Drop STAGE schema
    -- ==============================
    SET @sql_stmt = CONCAT('DROP SCHEMA IF EXISTS ', STAGE_SCHEMA_NAME);
    IF debug_mode_in THEN
      SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
    ELSE
      PREPARE query FROM @sql_stmt;
      EXECUTE query;
      DEALLOCATE PREPARE query;
      COMMIT;
    END IF;
  END; -- exec  
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END
$$

DELIMITER ;

SELECT '====> Procedure ''post_migration'' has been created' AS "Info:" FROM dual;
