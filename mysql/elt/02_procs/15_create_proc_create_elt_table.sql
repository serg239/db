/*
  Version:
    2011.12.11.01
  Script:
    15_create_proc_create_elt_table.sql
  Description:
    Create table in a given ELT schema.
  Input:
    * schema_type       - Schema Type. 
                          Values: 
                            * LINK  - Link (Federated Tables)
                            * DELTA - Static Tables
                            * STAGE - Static Tables
    * host_alias        - DB Host Alias.  
                          Values: [db1|db2]
    * shard_number      - Shard Number.
                          Values: [01|02|..]
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
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\15_create_proc_create_elt_table.sql
  Usage:
    CALL elt.create_elt_table (@err, 'LINK',  'db2', '01', 'catalog', 'content_item_external_item_mapping', FALSE);    -- db_link
    CALL elt.create_elt_table (@err, 'DELTA', 'db2', '01', 'catalog', 'content_item_external_item_mapping', FALSE);    -- db_delta   
    CALL elt.create_elt_table (@err, 'STAGE', 'db2', '01', 'catalog', 'content_item_external_item_mapping', FALSE);    -- db_stage
  Notes:
    
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.create_elt_table
$$

CREATE PROCEDURE elt.create_elt_table
(
  OUT error_code_out      INTEGER,
   IN schema_type_in      VARCHAR(16),      -- [LINK|STAGE|DELTA]
   IN host_alias_in       VARCHAR(16),      -- [db1|db2]
   IN shard_number_in     VARCHAR(2),       -- [01|02|...]
   IN src_schema_name_in  VARCHAR(64),
   IN src_table_name_in   VARCHAR(64),
   IN debug_mode_in       BOOLEAN
)
BEGIN

  DECLARE DB1_HOST_ALIAS             VARCHAR(16) DEFAULT 'db1';
  DECLARE DB2_HOST_ALIAS             VARCHAR(16) DEFAULT 'db2';

  DECLARE LINK_SCHEMA_TYPE           VARCHAR(8)  DEFAULT 'LINK';              -- link schema type
  DECLARE STAGE_SCHEMA_TYPE          VARCHAR(8)  DEFAULT 'STAGE';             -- stage schema type
  DECLARE DELTA_SCHEMA_TYPE          VARCHAR(8)  DEFAULT 'DELTA';             -- delta schema type

  DECLARE DB_LINK_TMP_SCHEMA_NAME  VARCHAR(64)  DEFAULT 'db_link_tmp'; -- link schema name - for META STAGE

  -- Input parameters
  DECLARE v_schema_type              VARCHAR(16) DEFAULT schema_type_in;  
  DECLARE v_host_alias               VARCHAR(16) DEFAULT host_alias_in;
  DECLARE v_shard_number             VARCHAR(2)  DEFAULT shard_number_in;
  DECLARE v_src_schema_name          VARCHAR(64) DEFAULT src_schema_name_in;
  DECLARE v_src_table_name           VARCHAR(64) DEFAULT src_table_name_in;

  DECLARE v_shard_table_name         VARCHAR(64); 
  DECLARE v_src_conn_str             VARCHAR(255);  -- Connection String
  DECLARE v_link_schema_name         VARCHAR(64);   -- LINK Schema name from src_tables table 
  DECLARE v_delta_schema_name        VARCHAR(64);   -- DELTA Schema name from src_tables table 
  DECLARE v_stage_schema_name        VARCHAR(64);   -- STAGE Schema name from src_tables table  

  DECLARE v_db_engine_type           VARCHAR(64);   -- [InnoDB|TokuDB] defined in src_tables

  DECLARE v_column_name              VARCHAR(64);
  DECLARE v_column_type              TEXT;
  DECLARE v_is_column_nullable       VARCHAR(3);
  DECLARE v_column_default           TEXT;
  DECLARE v_max_col_name_size        TINYINT;
  DECLARE v_table_column_def         TEXT;

  DECLARE v_index_name               VARCHAR(255);
  DECLARE v_index_non_unique         SMALLINT;
  DECLARE v_index_columns            VARCHAR(255);
  DECLARE v_index_column_def         TEXT;
  DECLARE v_index_type               VARCHAR(64);
  DECLARE v_tmp_str                  VARCHAR(64);

  DECLARE is_table_exists            INTEGER DEFAULT 0;
  DECLARE v_max_idx_length           INTEGER DEFAULT 64;

  DECLARE done                       BOOLEAN DEFAULT FALSE;

  -- ==================================
  -- Shards (COMMON)
  -- ==================================
  DECLARE src_tables_cur CURSOR
  FOR
    SELECT IFNULL(spf.shard_table_name, '')  AS shard_table_name,    -- ['shard_account_list'|'']
           CONCAT('mysql://', spf.db_user_name, ':', spf.db_user_pwd, '@', spf.host_ip_address, ':', spf.host_port_num) AS src_conn_str,
           st.link_schema_name,
           st.delta_schema_name,
           st.dst_schema_name,
           st.db_engine_type                                         -- [InnoDB|TokuDB]
      FROM elt.src_tables              st 
        INNER JOIN elt.shard_profiles  spf
          ON st.shard_profile_id = spf.shard_profile_id
            AND spf.status = 1                     -- active host profile
     WHERE spf.host_alias     = host_alias_in      -- [db1|db2]
       AND st.shard_number    = shard_number_in    -- [01|02|...] 
       AND st.src_schema_name = src_schema_name_in
       AND st.src_table_name  = src_table_name_in
       AND st.src_table_load_status  = 1        -- active SRC tables
       AND st.src_table_valid_status = 1;       -- valid SRC tables - for STAGE, DELTA, and LINK!!!

  -- ==================================
  -- Columns from SRC DB1 IS tables (STAGE)
  -- ==================================
  DECLARE src_db1_is_columns_cur CURSOR
  FOR
    SELECT CONCAT(CHAR(96),column_name,CHAR(96)) AS column_name,
           column_type,
           is_nullable,
           column_default,
           (SELECT MAX(LENGTH(column_name))
              FROM db_link_tmp.db1_information_schema_columns          -- Attn: Hardcoded "db_link_tmp" schema
             WHERE table_schema = v_src_schema_name
               AND table_name   = v_src_table_name
            ) + 2  AS max_col_name_size
      FROM db_link_tmp.db1_information_schema_columns                  -- Attn: Hardcoded "db_link_tmp" schema
     WHERE table_schema = v_src_schema_name
       AND table_name   = v_src_table_name
     GROUP BY column_name, column_type, is_nullable, column_default
     ORDER BY ordinal_position;

  -- ==================================
  -- Columns from SRC DB2 IS tables (STAGE)
  -- ==================================
  DECLARE src_db2_is_columns_cur CURSOR
  FOR
    SELECT CONCAT(CHAR(96),column_name,CHAR(96)) AS column_name,
           column_type,
           is_nullable,
           column_default,
           (SELECT MAX(LENGTH(column_name))
              FROM db_link_tmp.db2_information_schema_columns          -- Attn: Hardcoded "db_link_tmp" schema
             WHERE table_schema = v_src_schema_name
               AND table_name   = v_src_table_name
            ) + 2  AS max_col_name_size
      FROM db_link_tmp.db2_information_schema_columns                  -- Attn: Hardcoded "db_link_tmp" schema
     WHERE table_schema = v_src_schema_name
       AND table_name   = v_src_table_name
     GROUP BY column_name, column_type, is_nullable, column_default
     ORDER BY ordinal_position;

  -- ==================================
  -- Indexes from SRC DB1 IS tables (STAGE)
  -- ==================================
  DECLARE src_db1_is_indexes_cur CURSOR 
  FOR
    SELECT index_name,
           non_unique,
           GROUP_CONCAT(CONCAT(CHAR(96),column_name,CHAR(96)) ORDER BY seq_in_index SEPARATOR ', ')
      FROM db_link_tmp.db1_information_schema_indexes                  -- Attn: Hardcoded "db_link_tmp" schema
     WHERE index_schema = v_src_schema_name
       AND table_name   = v_src_table_name
     GROUP BY index_name, non_unique
     ORDER BY non_unique, index_name;

  -- ==================================
  -- Indexes from DB2 IS tables (STAGE)
  -- ==================================
  DECLARE src_db2_is_indexes_cur CURSOR 
  FOR
    SELECT index_name,
           non_unique,
           GROUP_CONCAT(CONCAT(CHAR(96),column_name,CHAR(96)) ORDER BY seq_in_index SEPARATOR ', ')
      FROM db_link_tmp.db2_information_schema_indexes                  -- Attn: Hardcoded "db_link_tmp" schema
     WHERE index_schema = v_src_schema_name
       AND table_name   = v_src_table_name
     GROUP BY index_name, non_unique
     ORDER BY non_unique, index_name;

  -- ==================================
  -- Columns from LOCAL tables (DELTA/LINK)
  -- ==================================
  DECLARE src_local_columns_cur CURSOR
  FOR
    SELECT CONCAT(CHAR(96),column_name,CHAR(96)) AS column_name,
           column_type,
           is_nullable,
           column_default,
           (SELECT MAX(LENGTH(column_name))
              FROM information_schema.columns                            -- Local IS
             WHERE table_schema = v_src_schema_name
               AND table_name   = v_src_table_name
            ) + 2  AS max_col_name_size
      FROM information_schema.columns                                    -- Local IS
     WHERE table_schema = v_src_schema_name
       AND table_name   = v_src_table_name
     GROUP BY column_name, column_type, is_nullable, column_default
     ORDER BY ordinal_position;

  -- ==================================
  -- Indexes from LOCAL tables (DELTA/LINK)
  -- ==================================
  DECLARE src_local_indexes_cur CURSOR 
  FOR
    SELECT index_name,
           non_unique,
           GROUP_CONCAT(CONCAT(CHAR(96),column_name,CHAR(96)) ORDER BY seq_in_index SEPARATOR ', ')
      FROM information_schema.statistics                                 -- Local IS
     WHERE index_schema = v_src_schema_name
       AND table_name   = v_src_table_name
     GROUP BY 1, 2
     ORDER BY non_unique, index_name;

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

    -- ================================
    -- Create FED tables to get STAGE table's meta
    -- ================================
    IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
      -- DB1
      CALL elt.create_info_link_fed_tables (@err_num, DB_LINK_TMP_SCHEMA_NAME, DB1_HOST_ALIAS, debug_mode_in);
      IF @err_num <> 0 THEN
        SELECT "Couldn't create info_link DB1 FED tables." AS "ERROR" FROM dual;
        SET error_code_out = -3;
        LEAVE exec;
      END IF;
      -- DB2
      CALL elt.create_info_link_fed_tables (@err_num, DB_LINK_TMP_SCHEMA_NAME, DB2_HOST_ALIAS, debug_mode_in);
      IF @err_num <> 0 THEN
        SELECT "Couldn't create info_link DB2 FED tables." AS "ERROR" FROM dual;
        SET error_code_out = -4;
        LEAVE exec;
      END IF;
    END IF;

    OPEN src_tables_cur;     -- F(host_alias_in, src_schema_name_in, src_table_name_in)

    -- ==================================
    -- Loop for all elt.src_tables having status = 1
    -- ==================================
    src_tables:
    LOOP

      SET done = FALSE;

      FETCH src_tables_cur
      INTO v_shard_table_name,         -- to exclude shard_account_list table from STAGE and DELTA schemas 
           v_src_conn_str,             -- Connection String for LINK tables
           v_link_schema_name,         -- LINK Schema Name for SRC table
           v_delta_schema_name,        -- DELTA Schema Name for SRC table
           v_stage_schema_name,        -- STAGE Schema Name for SRC table
           v_db_engine_type;           -- [InnoDB|TokuDB]

      IF done THEN
        LEAVE src_tables;
      END IF;

      IF (v_src_conn_str IS NULL) THEN
        SELECT "Couldn't get information about SRC tables. Check if SRC tables have been validated." AS "ERROR" FROM dual;
        SET error_code_out = -5;
        LEAVE src_tables;
      END IF;

      -- ==============================
      -- COLUMNS = F(src_schema_name_in, src_table_name_in) -> v_table_column_def
      -- ==============================
      SET v_table_column_def = '';

      SET error_code_out = -6;

      IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
        -- STAGE: open different COLUMN cursors (information schema = F(DBn)) 
        IF (host_alias_in = DB1_HOST_ALIAS) THEN
          OPEN src_db1_is_columns_cur;                     -- F(src_schema_name_in, src_table_name_in), FED in db_link_tmp
        ELSEIF (host_alias_in = DB2_HOST_ALIAS) THEN
          OPEN src_db2_is_columns_cur;                     -- F(src_schema_name_in, src_table_name_in), FED in db_link_tmp
        END IF;  
      ELSE  
        -- DELTA/LINK: Local IS
        OPEN src_local_columns_cur;                        -- F(src_schema_name_in, src_table_name_in), local IS
      END IF;

      -- ==============================
      src_db_columns:
      LOOP

        SET done = FALSE;

        IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
          IF (host_alias_in = DB1_HOST_ALIAS) THEN
            FETCH src_db1_is_columns_cur
             INTO v_column_name, v_column_type, v_is_column_nullable, v_column_default, v_max_col_name_size;
          ELSEIF (host_alias_in = DB2_HOST_ALIAS) THEN
            FETCH src_db2_is_columns_cur
             INTO v_column_name, v_column_type, v_is_column_nullable, v_column_default, v_max_col_name_size;
          END IF;  
        ELSE  
          -- DELTA/LINK - Local IS
          FETCH src_local_columns_cur
           INTO v_column_name, v_column_type, v_is_column_nullable, v_column_default, v_max_col_name_size;
        END IF;  
        
        -- check end of Loop (FETCH)
        IF done THEN
          SET done = FALSE;
          LEAVE src_db_columns;
        END IF;

        IF (v_table_column_def <> '') THEN
          SET v_table_column_def = CONCAT(v_table_column_def, ',', @LF);   -- add comma after the last column_def
        ELSE  
          SET v_table_column_def = '  ';
        END IF;

        SET v_table_column_def = CONCAT(v_table_column_def,
          IF (v_table_column_def = '  ', v_column_name, CONCAT('  ', v_column_name)),    -- name
          SPACE(v_max_col_name_size - LENGTH(v_column_name) + 1), UPPER(v_column_type),  -- type 
          IF (v_is_column_nullable = 'NO',
              CONCAT(SPACE(15 - LENGTH(v_column_type)), 'NOT NULL'),                     -- nullable [max length = 13, VARCHAR(2000)]
              IF ((v_column_type = "timestamp"),
                  CONCAT(SPACE(15 - LENGTH(v_column_type)), 'NULL'),
                  ""
                 ) -- IF 
             ),  -- IF
          IF (v_column_default IS NULL,                                                  -- default 
              "",
              CONCAT(" DEFAULT ",
                     IF ((SUBSTR(v_column_type, 1, POSITION("(" IN v_column_type) - 1) = "varchar") OR 
                         (v_column_type = "timestamp") OR 
                         (v_column_type = "date") OR 
                         (SUBSTR(v_column_type, 1, POSITION("(" IN v_column_type) - 1) = "enum"),
                         CASE v_column_default WHEN "0000-00-00 00:00:00" THEN "TIMESTAMP \'2000-01-01 00:00:00\'"
                                               WHEN "CURRENT_TIMESTAMP" THEN "CURRENT_TIMESTAMP"  -- remove asterisks
                                               ELSE CONCAT("\'", v_column_default, "\'")          -- add asterisks
                         END,
                         v_column_default
                        )  -- IF 
                    )  -- CONCAT
             )  -- IF
          );

        IF debug_mode_in THEN
          SELECT v_table_column_def  AS "Columns";
        END IF;  

      END LOOP;  -- for all TABLE Columns (src_dbX_columns_cur)
      -- ==============================

      -- close COLUMN cursor
      IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
        IF (host_alias_in = DB1_HOST_ALIAS) THEN
          CLOSE src_db1_is_columns_cur;
        ELSEIF (host_alias_in = DB2_HOST_ALIAS) THEN
          CLOSE src_db2_is_columns_cur;
        END IF;
      ELSE  
        -- DELTA/LINK: Local IS
        CLOSE src_local_columns_cur;
      END IF;  

      -- ==============================
      -- INDEXES = F(src_schema_name_in, src_table_name_in) -> v_index_column_def 
      -- ==============================
      SET v_index_column_def = '';

      SET error_code_out = -7;

      IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
        -- STAGE: open different INDEX cursors (information schema = F(DBn)) 
        IF (host_alias_in = DB1_HOST_ALIAS) THEN
          OPEN src_db1_is_indexes_cur;              -- F(src_schema_name_in, src_table_name_in), FED in db_link_tmp
        ELSEIF (host_alias_in = DB2_HOST_ALIAS) THEN
          OPEN src_db2_is_indexes_cur;              -- F(src_schema_name_in, src_table_name_in), FED in db_link_tmp
        END IF;  
      ELSE
        -- DELTA/LINK: Local IS
        OPEN src_local_indexes_cur;                 -- F(src_schema_name_in, src_table_name_in), local IS
      END IF;

      -- ==============================
      src_db_indexes:
      LOOP

        SET done = FALSE;

        -- get index (name, unique, columns)
        IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
          IF (host_alias_in = DB1_HOST_ALIAS) THEN
            FETCH src_db1_is_indexes_cur
            INTO v_index_name, v_index_non_unique, v_index_columns;
          ELSEIF (host_alias_in = DB2_HOST_ALIAS) THEN
            FETCH src_db2_is_indexes_cur
            INTO v_index_name, v_index_non_unique, v_index_columns;
          END IF;  
        ELSE
          -- DELTA/LINK: Local IS
          FETCH src_local_indexes_cur
          INTO v_index_name, v_index_non_unique, v_index_columns;
        END IF;

        IF done THEN
          SET done = FALSE;
          LEAVE src_db_indexes;
        END IF;

        IF LENGTH(v_index_column_def) > 1 THEN
          SET v_index_column_def = CONCAT(v_index_column_def, ',', @LF);  -- add comma
        END IF;

        -- INDEX Type
        IF (v_index_name = 'PRIMARY') THEN
          SET v_index_type = CONCAT(v_index_name, ' KEY ');
          SET v_tmp_str = CONCAT(SUBSTR(REPLACE(REPLACE(v_index_columns, CHAR(96), ''), ', ', '_'), 1, v_max_idx_length - 5), '_pk');
        ELSE
          IF (v_index_non_unique = 0) THEN
            SET v_index_type = 'UNIQUE KEY ';
            SET v_tmp_str = CONCAT(SUBSTR(REPLACE(REPLACE(v_index_columns, CHAR(96), ''), ', ', '_'), 1, v_max_idx_length - 7), '_uidx');
          ELSE
            SET v_index_type = 'KEY ';
            SET v_tmp_str = CONCAT(SUBSTR(REPLACE(REPLACE(v_index_columns, CHAR(96), ''), ', ', '_'), 1, v_max_idx_length - 6), '_idx');
          END IF;
        END IF;

        IF (schema_type_in = LINK_SCHEMA_TYPE) THEN
          SET v_index_name = CONCAT(SUBSTR(CONCAT(host_alias_in, '_', shard_number_in, '_', src_schema_name_in, '_', src_table_name_in), 1, v_max_idx_length - LENGTH(v_tmp_str) - 1), '$', v_tmp_str); 
          SET v_index_column_def = CONCAT(v_index_column_def, '  ',
                                          v_index_type, 
                                          v_index_name, ' ', 
                                          '(', v_index_columns, ')');  -- '\''
        ELSE
        --  SET v_index_name = CONCAT(SUBSTR(src_table_name_in, 1, v_max_idx_length - LENGTH(v_tmp_str) - 1), '$', v_tmp_str); 
          SET v_index_column_def = CONCAT(v_index_column_def, '  ',
                                          v_index_type,
                                          IF(v_index_name <> 'PRIMARY',
                                             v_index_name,
                                             ''
                                            ), ' ', 
                                          '(', v_index_columns, ')');
        END IF;
        IF debug_mode_in THEN
          SELECT v_index_column_def  AS "Indexes";
        END IF;  

      END LOOP;  -- for all TABLE Indexes (src_dbX_index_cur)
      -- ==============================

      -- close INDEX cursor
      IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
        IF (host_alias_in = DB1_HOST_ALIAS) THEN
          CLOSE src_db1_is_indexes_cur;
        ELSE
          CLOSE src_db2_is_indexes_cur;
        END IF;
      ELSE
        -- DELTA/LINK: Local IS
        CLOSE src_local_indexes_cur;
      END IF;  
    
      -- ==============================
      -- CREATE TABLE
      -- ==============================
      IF (schema_type_in = LINK_SCHEMA_TYPE) THEN

        SET error_code_out = -8;

        -- ==============================
        -- CREATE TABLE IN LINK SCHEMA
        -- ==============================
        SET @sql_stmt = CONCAT('CREATE TABLE IF NOT EXISTS ', v_link_schema_name, '.', host_alias_in, '_', shard_number_in, '_', src_schema_name_in, '_', src_table_name_in, @LF,
                               '(', @LF,
                               v_table_column_def, ',', @LF,
                               v_index_column_def, @LF,
                               ')', @LF,
                               'ENGINE = FEDERATED ', @LF,             -- FED only
                               'DEFAULT CHARSET = utf8 ', @LF,
                               'COLLATE = utf8_bin ', @LF,
                               'CONNECTION = ','\'',v_src_conn_str,'/',src_schema_name_in,'/',src_table_name_in,'\'' );

      ELSEIF (schema_type_in = DELTA_SCHEMA_TYPE) THEN

--        IF (src_table_name_in <> v_shard_table_name) THEN
          -- ==============================
          -- CREATE TABLE IN DELTA SCHEMA
          -- ==============================
          SET @sql_stmt = CONCAT('CREATE TABLE IF NOT EXISTS ', v_delta_schema_name, '.', src_table_name_in, @LF,
                                 '(', @LF,
                                 v_table_column_def, ',', @LF,
                                 v_index_column_def, @LF,
                                 ')', @LF,
                                 'ENGINE = ', v_db_engine_type, @LF,   -- [InnoDB|TokuDB]
                                 'DEFAULT CHARSET = utf8 ', @LF,
                                 'COLLATE = utf8_bin ');
--        END IF;                         

      ELSEIF (schema_type_in = STAGE_SCHEMA_TYPE) THEN

--        IF (src_table_name_in <> v_shard_table_name) THEN
          -- ==============================
          -- CREATE TABLE IN STAGE SCHEMA
          -- ==============================
          SET @sql_stmt = CONCAT('CREATE TABLE IF NOT EXISTS ', v_stage_schema_name, '.', src_table_name_in, @LF,
                                 '(', @LF,
                                 v_table_column_def, ',', @LF,
                                 v_index_column_def, @LF,
                                 ')', @LF,
                                 'ENGINE = ', v_db_engine_type, @LF,   -- [InnoDB|TokuDB]
                                 'DEFAULT CHARSET = utf8 ', @LF,
                                 'COLLATE = utf8_bin ');
--        END IF;
      ELSE
        SET @sql_stmt = '';
      END IF;

      IF LENGTH(@sql_stmt) > 1 THEN
        IF debug_mode_in THEN
          SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
          -- 
          COMMIT;
          --
        END IF;
      END IF;

    END LOOP;  -- for all TABLEs (src_db_tables)

    -- ================================

    CLOSE src_tables_cur;

    -- ================================
    -- Drop FED tables (was created to get STAGE table's meta)
    -- ================================
    IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
      CALL elt.drop_info_link_fed_tables (@err_num, DB_LINK_TMP_SCHEMA_NAME, debug_mode_in);
      IF @err_num <> 0 THEN
        SELECT "Couldn't drop info_link FED tables." AS "ERROR" FROM dual;
        SET error_code_out = -9;
        LEAVE exec;
      END IF;
    END IF; 

    SET error_code_out = 0;

  END;  -- exec

  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;

END
$$

DELIMITER ;

SELECT '====> Procedure ''create_elt_table'' has been created' AS "Info:" FROM dual;
