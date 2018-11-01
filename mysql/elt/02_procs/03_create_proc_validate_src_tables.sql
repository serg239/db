/*
  Version:
    2011.12.11.01
  Script:
    03_create_proc_validate_src_tables.sql
  Description:
    Check if DB tables in the elt.src_tables table are satisfying to the base 
    requirements for data migration:
    1. MASTER table should have 'modified_dtm' field
    2. LOG table should have 'log_modified_dtm' (db1) or 'log_created_dtm' (db2) field
    3. MASTER table should have a column with the same name as table name plus "_id"
    4. LOG table should have a field with the same name as PK column name of the corresponded MASTER table
    5. Indexes?
    and change src_table_valid_status 1 -> 0 (disable) if table is not satisfying the rule.
  Input:
    * host_alias         - Host Alias.   Values: [db1|db2|NULL]. 
    * src_schema_name    - SRC Schema Name (NULL if all tables/records in src_tables) 
    * src_table_name     - SRC Table Name  (NULL if all tables) 
    * debug_mode         - Debug Mode.
                           Values:
                             * FALSE (0) - execute SQL statements
                             * TRUE  (1) - show SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\03_create_proc_validate_src_tables.sql
  Usage:  
    CALL elt.validate_src_tables (@err, NULL, NULL, NULL, FALSE);
    CALL elt.validate_src_tables (@err, 'db1', 'account', 'account_log', FALSE);
*/
DELIMITER $$ 

DROP PROCEDURE IF EXISTS elt.validate_src_tables$$

CREATE PROCEDURE elt.validate_src_tables
(
 OUT error_code_out      INTEGER,
  IN host_alias_in       VARCHAR(16),   -- [db1|db2|NULL] 
  IN src_schema_name_in  VARCHAR(64),   -- could be NULL
  IN src_table_name_in   VARCHAR(64),   -- could be NULL (all tables) 
  IN debug_mode_in       BOOLEAN
) 
BEGIN

  DECLARE DB1_HOST_ALIAS           VARCHAR(16) DEFAULT 'db1';
  DECLARE DB2_HOST_ALIAS           VARCHAR(16) DEFAULT 'db2';

  DECLARE LINK_TMP_SCHEMA_NAME     VARCHAR(64) DEFAULT 'db_link_tmp';

  DECLARE MDF_DTM_COL_NAME         VARCHAR(64) DEFAULT 'modified_dtm';        -- default
  DECLARE LAST_MOD_TIME_COL_NAME   VARCHAR(64) DEFAULT 'last_mod_time';       -- in DB2.load_catalog schema
  DECLARE LOG_CRT_DTM_COL_NAME     VARCHAR(64) DEFAULT 'log_created_dtm';     -- default 
  DECLARE LOG_MDF_DTM_COL_NAME     VARCHAR(64) DEFAULT 'log_modified_dtm';    -- in DB1.account schema

  DECLARE NO_TABLE                 VARCHAR(128) DEFAULT 'The table <table_name> has been removed from the schema';
  DECLARE NO_PK_ON_TABLE           VARCHAR(128) DEFAULT 'There is no PK on Master table';
  DECLARE NO_DTM_COLUMN            VARCHAR(128) DEFAULT 'There is no column for data processing';
  DECLARE NO_FK_TO_MASTER          VARCHAR(128) DEFAULT 'There is no FK to Master table';

  DECLARE v_host_alias             VARCHAR(16);     -- [db1|db2|NULL]
  DECLARE v_src_schema_name        VARCHAR(64) DEFAULT src_schema_name_in;
  DECLARE v_src_table_name         VARCHAR(64) DEFAULT src_table_name_in;
  DECLARE v_src_table_type         VARCHAR(16);                            -- [MASTER|LOG]
  DECLARE v_shard_schema_name      VARCHAR(64);
  DECLARE v_shard_table_name       VARCHAR(64);

  DECLARE v_comments_str           VARCHAR(256) DEFAULT '';
  DECLARE v_is_modified_dtm_field  BOOLEAN DEFAULT FALSE;

  DECLARE done                     BOOLEAN DEFAULT FALSE;

  DECLARE main_src_tables_cur CURSOR
  FOR
  SELECT spf.host_alias,               -- [db1|db2]
         st.src_table_type,            -- [MASTER|LOG]
         st.src_schema_name,
         st.src_table_name,
         spf.shard_schema_name,
         spf.shard_table_name
    FROM elt.src_tables              st
      INNER JOIN elt.shard_profiles  spf
        ON st.shard_profile_id = spf.shard_profile_id
          AND spf.status = 1           -- active host profile
   WHERE st.src_table_load_status = 1  -- only active SRC tables
   ORDER BY st.src_table_id
  ;

  DECLARE main_src_table_cur CURSOR
  FOR
  SELECT st.src_table_type,            -- [MASTER|LOG]
         spf.shard_schema_name,
         spf.shard_table_name
    FROM elt.src_tables              st
      INNER JOIN elt.shard_profiles  spf
        ON st.shard_profile_id = spf.shard_profile_id
          AND spf.status = 1           -- active host profile
   WHERE st.host_alias      = v_host_alias
     AND st.src_schema_name = v_src_schema_name
     AND st.src_table_name  = v_src_table_name
     AND st.src_table_load_status = 1  -- only active SRC table
  ;

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
    
    IF (host_alias_in IS NULL) AND (src_schema_name_in IS NULL) AND (src_table_name_in IS NULL) THEN
      OPEN main_src_tables_cur;
    ELSEIF (host_alias_in IS NOT NULL) AND (src_schema_name_in IS NOT NULL) AND (src_table_name_in IS NOT NULL) THEN
      --
      SET v_host_alias = LOWER(host_alias_in);
      --
      OPEN main_src_table_cur;
      --
    ELSE
      SELECT CONCAT('Host [', host_alias_in, '] OR Schema [', src_schema_name_in, '] OR Table [', src_table_name_in, '] is not defined') AS "ERROR" FROM dual;
      SET error_code_out = -3;
      LEAVE exec;
    END IF;

    SET error_code_out = -4;

    -- ================================
    -- Create temporary FED tables to remote IS in db_link schema
    -- ================================
    CALL elt.create_info_link_fed_tables (@err_num, LINK_TMP_SCHEMA_NAME, v_host_alias, debug_mode_in);
    IF (@err_num <> 0) THEN
      SELECT CONCAT('Procedure \'create_info_link_tables\', schema ''', LINK_TMP_SCHEMA_NAME, ''', ERROR: ', @err_num);
      LEAVE exec;
    END IF;

    -- ================================
    -- For All Tables or just a given Table
    -- ================================
    main_src_tables:
    LOOP

      SET done = FALSE;

      IF src_table_name_in IS NULL THEN
        -- all tables
        FETCH main_src_tables_cur
         INTO v_host_alias,             -- [db1|db2]
              v_src_table_type,         -- [MASTER|LOG]
              v_src_schema_name,
              v_src_table_name,
              v_shard_schema_name,      -- shard_account_list is for LINK schema only 
              v_shard_table_name;
      ELSE
        -- given table
        FETCH main_src_table_cur
         INTO v_src_table_type,         -- [MASTER|LOG]
              v_shard_schema_name,      -- shard_account_list is for LINK schema only 
              v_shard_table_name;
      END IF;

      IF v_src_table_type IS NULL THEN
        SELECT "Couldn't get information about SRC tables. Check 'status' of the Host Profiles or 'load_status' of the SRC tables." AS "ERROR" FROM dual;
        SET error_code_out = -5;
        LEAVE main_src_tables;
      END IF;

      IF done THEN
        LEAVE main_src_tables;
      END IF;

      -- Comments
      SET v_comments_str = '';

      -- ======================================================================
      -- 0. Check if table exists
      -- 1. MASTER table should have 'modified_dtm' field
      -- 2. LOG table should have 'log_modified_dtm' (db1) or 'log_created_dtm' (db2) field
      -- 3. MASTER table should have a column with the same name as table name plus "_id"
      --    => [hidden] PK of Master Table. 
      -- 4. LOG table should have a field with the same name as PK column name 
      --    of the corresponded MASTER table => [hidden] FK to Master Table. 
      -- ======================================================================

      -- ======================================================================
      -- 0. Check if remote table exists
      -- ======================================================================
      SET @is_table_exists = FALSE;
      IF (v_host_alias = DB1_HOST_ALIAS) THEN
        SET @sql_stmt = CONCAT(@LF,
          'SELECT TRUE ', @LF,
          '  INTO @is_table_exists', @LF,
          '  FROM ', LINK_TMP_SCHEMA_NAME, '.db1_information_schema_columns', @LF,
          ' WHERE table_schema = ''', v_src_schema_name, '''', @LF,
          '   AND table_name   = ''', v_src_table_name, '''', @LF,
          ' LIMIT 1');
      ELSEIF (v_host_alias = DB2_HOST_ALIAS) THEN
        SET @sql_stmt = CONCAT(@LF,
          'SELECT TRUE ', @LF,
          '  INTO @is_table_exists', @LF,
          '  FROM ', LINK_TMP_SCHEMA_NAME, '.db2_information_schema_columns', @LF,
          ' WHERE table_schema = ''', v_src_schema_name, '''', @LF,  
          '   AND table_name   = ''', v_src_table_name, '''', @LF, 
          ' LIMIT 1');
      ELSE
        SET error_code_out = -6;
        LEAVE main_src_tables;
      END IF;

      IF debug_mode_in THEN
        SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
        COMMIT;
      END IF;

      IF NOT @is_table_exists THEN
        -- Table is not valid (on all shards)
        SET @sql_stmt = CONCAT(@LF,
          'UPDATE elt.src_tables', @LF,
          '   SET src_table_valid_status = 0,', @LF,
          '       comments          = REPLACE (''', NO_TABLE, ''', ''<table_name>'', ''', v_src_table_name, '''),', @LF,
          '       modified_by       = ''', SUBSTRING_INDEX(USER(), "@", 1), ''',', @LF,
          '       modified_at       = ''', CURRENT_TIMESTAMP(), '''', @LF,
          ' WHERE host_alias      = ''', v_host_alias, '''', @LF,
          '   AND src_schema_name = ''', v_src_schema_name, '''', @LF,
          '   AND src_table_name  = ''', v_src_table_name, ''''
          );
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
          COMMIT;
        END IF;

      ELSE
        -- ============================
        -- Table does exist (status = 1) --> valid on all shards of the project's name/type 
        -- ============================
        SET @sql_stmt = CONCAT(@LF,
          'UPDATE elt.src_tables', @LF,
          '   SET src_table_valid_status = 1,', @LF,
          '       comments               = NULL,', @LF,
          '       modified_by            = ''', SUBSTRING_INDEX(USER(), "@", 1), ''',', @LF,
          '       modified_at            = ''', CURRENT_TIMESTAMP(), '''', @LF,
          ' WHERE host_alias      = ''', v_host_alias, '''', @LF,
          '   AND src_schema_name = ''', v_src_schema_name, '''', @LF,
          '   AND src_table_name  = ''', v_src_table_name, ''''
          );
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
          COMMIT;
        END IF;
        
        SET v_is_modified_dtm_field = FALSE;

        IF (v_src_table_type = 'MASTER') THEN
          -- ======================================================================
          -- 1. MASTER table should have 'modified_dtm' or 'last_mod_time' field
          -- ======================================================================
          SET @is_modified_dtm_field = FALSE;

          IF (v_host_alias = DB1_HOST_ALIAS) THEN
            SET @sql_stmt = CONCAT(@LF,
              'SELECT TRUE', @LF,
              '  INTO @is_modified_dtm_field', @LF,
              '  FROM ', LINK_TMP_SCHEMA_NAME, '.db1_information_schema_columns', @LF,
              ' WHERE table_schema = ''', v_src_schema_name, '''', @LF,
              '   AND table_name   = ''', v_src_table_name, '''',  @LF,
              '   AND LOWER(column_name) = ''', MDF_DTM_COL_NAME, '''');       -- DB1: 'modified_dtm'
          ELSEIF (v_host_alias = DB2_HOST_ALIAS) THEN
            SET @sql_stmt = CONCAT(@LF,
              'SELECT TRUE', @LF,
              '  INTO @is_modified_dtm_field', @LF,
              '  FROM ', LINK_TMP_SCHEMA_NAME, '.db2_information_schema_columns', @LF,
              ' WHERE table_schema = ''', v_src_schema_name, '''', @LF,
              '   AND table_name   = ''', v_src_table_name, '''',  @LF,
              '   AND (LOWER(column_name) = ''', MDF_DTM_COL_NAME, '''', @LF,     -- DB2: 'modified_dtm' OR
              '   OR LOWER(column_name)   = ''', LAST_MOD_TIME_COL_NAME, '''');   -- DB2: 'last_mod_time' in load_catalog schema
          ELSE
            SET error_code_out = -7;
            LEAVE main_src_tables;
          END IF;
          IF debug_mode_in THEN
            SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
            COMMIT;
          END IF;

          IF NOT @is_modified_dtm_field THEN
            IF ((v_src_schema_name <> v_shard_schema_name) AND (v_src_table_name <> v_shard_table_name)) THEN
              -- if not sharding table
              SET v_comments_str = CONCAT(v_comments_str, NO_DTM_COLUMN, '; ');
            END IF;              
          END IF; -- IF @is_modified_dtm_field IS NULL  

          -- ======================================================================
          -- XXX 2. MASTER table should have a column with the same name as table name plus "_id" XXX
          -- 2. MASTER table should have a Primary key
          -- ======================================================================
          SET @is_master_pk_column = FALSE;

          IF (v_host_alias = DB1_HOST_ALIAS) THEN
            SET @sql_stmt = CONCAT(@LF,
              'SELECT TRUE', @LF,
              '  INTO @is_master_pk_column', @LF,
              '  FROM ', LINK_TMP_SCHEMA_NAME, '.db1_information_schema_columns col_db1', @LF,
              ' WHERE col_db1.table_schema = ''', v_src_schema_name, '''', @LF,
              '   AND col_db1.table_name   = ''', v_src_table_name, '''',  @LF,
--            '   AND col_db1.column_name  = CONCAT(col_db1.table_name, "_id")', @LF,
              '   AND col_db1.column_key   = "PRI"');
          ELSEIF (v_host_alias = DB2_HOST_ALIAS) THEN -- db2
            SET @sql_stmt = CONCAT(@LF,
              'SELECT TRUE', @LF,
              '  INTO @is_master_pk_column', @LF,
              '  FROM ', LINK_TMP_SCHEMA_NAME, '.db2_information_schema_columns col_db2', @LF,
              ' WHERE col_db2.table_schema = ''', v_src_schema_name, '''', @LF,
              '   AND col_db2.table_name   = ''', v_src_table_name, '''',  @LF,
--            '   AND col_db2.column_name  = CONCAT(col_db2.table_name, "_id")', @LF,
              '   AND col_db2.column_key   = "PRI"');
          END IF;
          IF debug_mode_in THEN
            SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
          END IF; 

          IF NOT @is_master_pk_column THEN
            IF ((v_src_schema_name <> v_shard_schema_name) AND (v_src_table_name <> v_shard_table_name)) THEN
              SET v_comments_str = CONCAT(v_comments_str, NO_PK_ON_TABLE, '; ');
            END IF;  
          END IF;  -- NOT @is_master_pk_column

        ELSE

          -- ======================================================================
          -- 3. LOG table should have 'log_modified_dtm' (db1) or 'log_created_dtm' (db2) field
          -- ======================================================================
          SET @is_modified_dtm_field = FALSE;

          IF (v_host_alias = DB1_HOST_ALIAS) THEN
            SET @sql_stmt = CONCAT(@LF,
              'SELECT TRUE', @LF,
              '  INTO @is_modified_dtm_field', @LF,
              '  FROM ', LINK_TMP_SCHEMA_NAME, '.db1_information_schema_columns col_db1', @LF,
              ' WHERE table_schema = ''', v_src_schema_name, '''', @LF, 
              '   AND table_name   = ''', v_src_table_name, '''',  @LF,
              '   AND LOWER(column_name) = ''', LOG_MDF_DTM_COL_NAME, '''');   -- DB1: 'log_modified_dtm'
          ELSEIF (v_host_alias = DB2_HOST_ALIAS) THEN
            SET @sql_stmt = CONCAT(@LF,
              'SELECT TRUE', @LF,
              '  INTO @is_modified_dtm_field', @LF,
              '  FROM ', LINK_TMP_SCHEMA_NAME, '.db2_information_schema_columns col_db1', @LF,
              ' WHERE table_schema = ''', v_src_schema_name, '''', @LF, 
              '   AND table_name   = ''', v_src_table_name, '''',  @LF,
              '   AND LOWER(column_name) = ''', LOG_CRT_DTM_COL_NAME, '''');   -- DB2: 'log_created_dtm'
          ELSE
            SET error_code_out = -8;
            LEAVE main_src_tables;
          END IF;
          IF debug_mode_in THEN
            SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
          END IF; 

          IF NOT @is_modified_dtm_field THEN
            IF ((v_src_schema_name <> v_shard_schema_name) AND (v_src_table_name <> v_shard_table_name)) THEN
              SET v_comments_str = CONCAT(v_comments_str, NO_DTM_COLUMN, '; ');
            END IF;
          END IF; -- IF @is_modified_dtm_field IS NULL  

          -- ======================================================================
          -- 4. LOG table should have a field with the same name as PK column name 
          --    of the corresponded MASTER table => [hidden] FK to Master Table. 
          -- ======================================================================
          SET @is_log_to_master_pk_column = FALSE;

          IF (v_host_alias = DB1_HOST_ALIAS) THEN
            SET @sql_stmt = CONCAT(@LF,
              'SELECT TRUE', @LF,
              '  INTO @is_log_to_master_pk_column', @LF,
              '  FROM ', LINK_TMP_SCHEMA_NAME, '.db1_information_schema_columns          col_db11', @LF,
              '    INNER JOIN ', LINK_TMP_SCHEMA_NAME, '.db1_information_schema_columns  col_db12', @LF,
              '      ON col_db12.table_schema   = col_db11.table_schema', @LF,
              '        AND col_db12.table_name  = REPLACE(col_db11.table_name, "_log", "")', @LF,
              '        AND col_db12.column_name = col_db11.column_name',   @LF,
              ' WHERE col_db11.table_schema = ''', v_src_schema_name, '''', @LF,
              '   AND col_db11.table_name   = ''', v_src_table_name, '''',  @LF,
              '   AND col_db12.column_key   = "PRI"');
          ELSEIF (v_host_alias = DB2_HOST_ALIAS) THEN
            SET @sql_stmt = CONCAT(@LF,
              'SELECT TRUE', @LF,
              '  INTO @is_log_to_master_pk_column', @LF,
              '  FROM ', LINK_TMP_SCHEMA_NAME, '.db2_information_schema_columns          col_db21', @LF,
              '    INNER JOIN ', LINK_TMP_SCHEMA_NAME, '.db2_information_schema_columns  col_db22', @LF,
              '      ON col_db22.table_schema   = col_db21.table_schema', @LF,
              '        AND col_db22.table_name  = REPLACE(col_db21.table_name, "_log", "")', @LF,
              '        AND col_db22.column_name = col_db21.column_name',    @LF,
              ' WHERE col_db21.table_schema = ''', v_src_schema_name, '''', @LF,
              '   AND col_db21.table_name   = ''', v_src_table_name, '''',  @LF,
              '   AND col_db22.column_key   = "PRI"');
          END IF;
          IF debug_mode_in THEN
            SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
          END IF; 

          IF NOT @is_log_to_master_pk_column THEN
            SET v_comments_str = CONCAT(v_comments_str, NO_FK_TO_MASTER, '; ');
          END IF;  -- IF v_is_modified_dtm_field IS NULL

        END IF;  -- IF-ELSE (v_src_table_type = 'MASTER')

        --
        -- Update comments
        --
        IF LENGTH(v_comments_str) > 1 THEN
          SET v_comments_str = (SELECT TRIM(TRAILING '; ' FROM v_comments_str));
          SET @sql_stmt = CONCAT(@LF,
            'UPDATE elt.src_tables', @LF,
            '   SET comments        = ''', v_comments_str, ''',', @LF,
            '       modified_by     = ''', SUBSTRING_INDEX(USER(), "@", 1), ''',', @LF,
            '       modified_at     = ''', CURRENT_TIMESTAMP(), '''', @LF,
            ' WHERE host_alias      = ''', v_host_alias, '''', @LF,
            '   AND src_schema_name = ''', v_src_schema_name, '''', @LF,
            '   AND src_table_name  = ''', v_src_table_name, ''''
            );
          IF debug_mode_in THEN
            SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
            COMMIT;
          END IF;
        END IF; -- IF LENGTH(v_comments_str) > 1
      
      END IF; -- IF-ELSE @is_table_exists IS NULL

    END LOOP;  -- main_src_tables
    -- ================================

    IF src_table_name_in IS NULL THEN
      CLOSE main_src_tables_cur;
    ELSE
      CLOSE main_src_table_cur;
    END IF;

    -- ================================
    -- Drop temporary FED tables and Schema
    -- ================================
    CALL elt.drop_info_link_fed_tables (@err_num, LINK_TMP_SCHEMA_NAME, debug_mode_in);
    IF (@err_num <> 0) THEN
      SELECT CONCAT('Procedure \'drop_info_link_tables\', schema ''', LINK_TMP_SCHEMA_NAME, ''', ERROR: ', @err_num);
      LEAVE exec;
    END IF;
    
    SET error_code_out = 0; 

  END;  -- exec:  

  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;

END$$

DELIMITER ;

SELECT '====> Procedure ''validate_src_tables'' has been created' AS "Info:" FROM dual;
