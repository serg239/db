/*
  Version:
    2011.11.12.01
  Script:
    06_create_proc_add_elt_table.sql
  Description:
    Add table to ELT process.
  Schema:
         host_alias +----------------------------------+
           +--------|              procedure           |
           |   +--->|                                  |  
           |   |    +----------------------------------+
           |   | shard_profile_id  |         |
           |   | shard_number      | INSERT  | CREATE TABLE
           |   | conn_str (LINK)   | (**)    |
           v   |                   v         |       {
    shard_profiles             src_tables    |        host, shard,
  +-----------------+       +------------+   |        schema, table,
  |                 |       | 1          |   |        override_dtm = '2000-01-01',
  +-----------------+       | 2          |   |        alias, type, 
      status = 1            |...         |   |        dtm_column, proc_pk_column,
                            | N          |   |        block_size,
                            +------------+   |        load_status = 1, valid_status = ?
                                             |       }
                           +-----------------+-----------------+
                           |                 |                 |
                           v                 v                 v
                        LINK (*)         STAGE (*)         DELTA (*)
                   +-------------+    +-------------+    +-------------+
                   | 1           |    | 1           |    | 1           |
                   | 2           |    |             |    |             |
                   |...          |    |             |    |             |
                   | N           |    |             |    |             |
                   +-------------+    +-------------+    +-------------+
                    N FED tables      1 InnoDB table     1 InnoDB table
  (*) If schema exists
  (**) CALL elt.fill_src_tables (@err, <host_alias>, <schema>, <table>, NULL, NULL, NULL, ';', FALSE);
    
  Input:
    * schema_type     - Schema Type      [STAGE|DELTA|LINK|NULL]
                                         If NULL - create table in local schema having SRC Schema Name (DDL)
    * host_alias      - Host Alias       [db1|db2]
    * src_schema_name - SRC Schema Name.
    * src_table_name  - SRC Table Name.
    * db_engine_type  - DB Engine        [InnoDB|TokuDB|...]   
    * debug_mode      - Debug Mode.
                        Values:
                          * TRUE  (1) - show SQL statements
                          * FALSE (0) - execute SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * -2: common error
      * -3: wrong schema type (schema_type_in)
      * -4: table has been already created
  Istall:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\06_create_proc_add_elt_table.sql
  Usage (display SQL only):

    -- db1: account_brand
    CALL elt.add_elt_table (@err, 'DELTA', 'db1', 'account', 'account_brand', 'InnoDB', FALSE);
    CALL elt.add_elt_table (@err, 'DELTA', 'db1', 'account', 'account_brand_log', 'InnoDB', FALSE);
    -- db1: account_user
    CALL elt.add_elt_table (@err, 'DELTA', 'db1', 'account', 'account_user', 'InnoDB', FALSE);
    CALL elt.add_elt_table (@err, 'DELTA', 'db1', 'account', 'account_user_log', 'InnoDB', FALSE);
    -- db1:
    CALL elt.add_elt_table (@err, 'DELTA', 'db1', 'account', 'account_status', 'InnoDB', FALSE);
    CALL elt.add_elt_table (@err, 'DELTA', 'db1', 'account', 'account_type_lookup', 'InnoDB', FALSE);
    -- db2: OLAP
    CALL elt.add_elt_table (@err, 'DELTA', 'db2', 'load_catalog', 'content_item_class_attr_values', 'InnoDB', FALSE);
    CALL elt.add_elt_table (@err, 'DELTA', 'db2', 'load_catalog', 'count_ci_per_shelf', 'InnoDB', FALSE);
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.add_elt_table
$$

CREATE PROCEDURE elt.add_elt_table
(
  OUT error_code_out     INTEGER,
   IN schema_type_in     VARCHAR(16),   -- Schema Type    [DELTA|LINK|NULL]
   IN host_alias_in      VARCHAR(16),   -- Host Alias     [db1|db2]
   IN src_schema_name_in VARCHAR(64),   -- SRC schema name
   IN src_table_name_in  VARCHAR(64),   -- SRC table name
   IN db_engine_type_in  VARCHAR(64),   -- DB Engine Type [InnoDB|TokuDB|...]
   IN debug_mode_in      BOOLEAN
)
BEGIN

  -- Constants
  DECLARE DB1_HOST_ALIAS         VARCHAR(16) DEFAULT 'db1';
  DECLARE DB2_HOST_ALIAS         VARCHAR(16) DEFAULT 'db2';

  DECLARE LINK_SCHEMA_TYPE       VARCHAR(16) DEFAULT 'LINK';
  DECLARE DELTA_SCHEMA_TYPE      VARCHAR(16) DEFAULT 'DELTA';

  DECLARE LINK_SCHEMA_NAME       VARCHAR(64) DEFAULT 'db_link';
  DECLARE STAGE_SCHEMA_NAME      VARCHAR(64) DEFAULT 'db_stage';
  DECLARE DELTA_SCHEMA_NAME      VARCHAR(64) DEFAULT 'db_delta';

  -- Input parameters
  DECLARE v_schema_type          VARCHAR(16) DEFAULT schema_type_in;  
  DECLARE v_host_alias           VARCHAR(16) DEFAULT host_alias_in;
  DECLARE v_src_schema_name      VARCHAR(64) DEFAULT src_schema_name_in;
  DECLARE v_src_table_name       VARCHAR(64) DEFAULT src_table_name_in;
  DECLARE v_db_engine_type       VARCHAR(64) DEFAULT db_engine_type_in;
  
  -- Shard Info
  DECLARE v_shard_number         CHAR(2);       -- Shard Number
  DECLARE v_src_conn_str         VARCHAR(255);  -- Connection String

  -- Sharding
  DECLARE v_shard_schema_name    VARCHAR(64);
  DECLARE v_shard_table_name     VARCHAR(64);

  -- Columns
  DECLARE v_column_name          VARCHAR(64);
  DECLARE v_column_type          TEXT;
  DECLARE v_is_column_nullable   VARCHAR(3);
  DECLARE v_column_default       TEXT;
  DECLARE v_max_col_name_size    TINYINT;
  DECLARE v_table_column_def     TEXT;

  -- Indexes
  DECLARE v_index_name           VARCHAR(255);
  DECLARE v_index_non_unique     SMALLINT;
  DECLARE v_index_columns        VARCHAR(255);
  DECLARE v_index_column_def     TEXT;
  DECLARE v_index_type           VARCHAR(64);
  DECLARE v_max_idx_length       INTEGER DEFAULT 64;

  -- Others
  DECLARE is_sch_exists          BOOLEAN DEFAULT FALSE;  -- 0
  DECLARE is_table_exists        BOOLEAN DEFAULT FALSE;  -- 0
  DECLARE done                   BOOLEAN DEFAULT FALSE;
  DECLARE v_tmp_str              VARCHAR(64);

  -- Shard Information
  DECLARE shard_info_cur CURSOR
  FOR
    SELECT DISTINCT IFNULL(shard_schema_name, ''),
           IFNULL(shard_table_name, '')
      FROM elt.shard_profiles   spf
     WHERE host_alias = v_host_alias
       AND status     = 1;              -- active shard

  -- Shard Connection
  DECLARE shard_conn_cur CURSOR
  FOR
    SELECT spf.shard_number,
           CONCAT('mysql://', spf.db_user_name, ':', spf.db_user_pwd, '@', spf.host_ip_address, ':', spf.host_port_num) AS src_conn_str
      FROM elt.shard_profiles   spf
     WHERE spf.host_alias = v_host_alias   -- host
       AND spf.status     = 1;             -- active shard

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

  SET @LF = CHAR(10); 

  exec:
  BEGIN

    SET error_code_out = -2;
    
    SET v_schema_type = UPPER(v_schema_type);

    -- ================================
    -- Check environment
    -- ================================
    SET is_sch_exists = FALSE; 
    IF (v_schema_type = DELTA_SCHEMA_TYPE) THEN
      SELECT TRUE
        INTO is_sch_exists
        FROM information_schema.schemata 
       WHERE schema_name = DELTA_SCHEMA_NAME;
    ELSEIF (v_schema_type = LINK_SCHEMA_TYPE) THEN
      SELECT TRUE 
        INTO is_sch_exists
        FROM information_schema.schemata 
       WHERE schema_name = LINK_SCHEMA_NAME;
    ELSE
      SELECT TRUE 
        INTO is_sch_exists
        FROM information_schema.schemata 
       WHERE schema_name = v_src_schema_name;
    END IF;   
    IF (NOT is_sch_exists) THEN
      SET error_code_out = -3;
      LEAVE exec;
    END IF;

    -- ================================
    -- Check if record about table is already exists
    -- ================================
    IF v_schema_type IS NOT NULL THEN
      -- [STAGE|DELTA|LINK]
      SET is_table_exists = FALSE;
      SELECT TRUE
        INTO is_table_exists
        FROM elt.src_tables
       WHERE host_alias      = v_host_alias
         AND src_schema_name = v_src_schema_name
         AND src_table_name  = v_src_table_name;
      IF NOT is_table_exists THEN
        -- Add records to src_tables (for all shards, create/drop FED IS tables)
        CALL elt.populate_src_tables (@err, v_host_alias, v_db_engine_type, v_src_schema_name, v_src_table_name, NULL, NULL, NULL, ';', debug_mode_in);
        -- Validate table - do not validate new table
        CALL elt.validate_src_tables (@err, v_host_alias, v_src_schema_name, v_src_table_name, debug_mode_in);
      END IF;
    END IF;  

    --
    -- Get information about columns and indexes on a given table
    --
    -- ====================================================
    -- COLUMNS = F(DB, TABLE)
    -- ====================================================
    SET v_table_column_def = '';

    OPEN src_local_columns_cur;

    -- ================================
    src_db_columns:
    LOOP
      SET done = FALSE;

      FETCH src_local_columns_cur
      INTO v_column_name, v_column_type, v_is_column_nullable, v_column_default, v_max_col_name_size;

      -- check end of Loop (FETCH)
      IF done THEN
        SET done = FALSE;
        LEAVE src_db_columns;
      END IF;

      -- Debug
      IF debug_mode_in THEN
        SELECT CONCAT('Name: ', v_column_name, '; Type: ', v_column_type, '; Null: ', v_is_column_nullable, '; Default: ', IFNULL(v_column_default, ''), '; MaxSize: ', v_max_col_name_size) AS "Type_Default";
      END IF;

      -- concatenate column rows
      IF LENGTH(v_table_column_def) > 1 THEN
        SET v_table_column_def = CONCAT(v_table_column_def, ',', @LF);
      ELSE  
        SET v_table_column_def = SPACE(2);
      END IF;

      SET v_table_column_def = CONCAT(v_table_column_def,
                                      IF (LENGTH(v_table_column_def) = 2, 
                                          v_column_name,
                                          CONCAT('  ', v_column_name)
                                         ),                                                                             -- name
                                         SPACE(v_max_col_name_size - LENGTH(v_column_name) + 1), 
                                         UPPER(v_column_type),                                                          -- type 
                                         IF (v_is_column_nullable = 'NO',
                                             CONCAT(SPACE(15 - LENGTH(v_column_type)), 'NOT NULL'), -- nullable [max length = 13, VARCHAR(2000)]
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
                                     );  -- CONCAT

    END LOOP;  -- for all Columns -> v_table_column_def
    -- ================================
    -- close COLUMN cursor
    CLOSE src_local_columns_cur;

    -- ====================================================
    -- INDEXES = F(DB, TABLE)
    -- !!! Attn !!! Not for LINK tables
    -- ====================================================
    IF (v_schema_type IS NULL) OR (v_schema_type <> LINK_SCHEMA_TYPE) THEN

      -- Indexes for DELTA table
      SET v_index_column_def  = '';

      OPEN src_local_indexes_cur;
      -- ================================
      src_db_indexes:
      LOOP
        SET done = FALSE;

        -- get index (name, unique, columns)
        FETCH src_local_indexes_cur
        INTO v_index_name, v_index_non_unique, v_index_columns;

        IF done THEN
          SET done = FALSE;
          LEAVE src_db_indexes;
        END IF;

        -- Concatenate index rows
        IF LENGTH(v_index_column_def) > 1 THEN
          SET v_index_column_def  = CONCAT(v_index_column_def, ',', @LF);
        END IF;

        -- INDEX Type
        IF (v_index_name = 'PRIMARY') THEN
          SET v_index_type = CONCAT(v_index_name, ' KEY ');
          -- SET v_tmp_str = CONCAT(SUBSTR(REPLACE(v_index_columns, ', ', '_'), 1, v_max_idx_length - 5), '_pk');
        ELSE
          IF (v_index_non_unique = 0) THEN
            SET v_index_type = 'UNIQUE KEY ';
            -- SET v_tmp_str = CONCAT(SUBSTR(REPLACE(v_index_columns, ', ', '_'), 1, v_max_idx_length - 7), '_uidx');
          ELSE
            SET v_index_type = 'KEY ';
            -- SET v_tmp_str = CONCAT(SUBSTR(REPLACE(v_index_columns, ', ', '_'), 1, v_max_idx_length - 6), '_idx');
          END IF;
        END IF;

        -- ATTN: Could not change the index names in new tables
        -- SET v_index_column_def = CONCAT(v_index_column_def, '  ',
        --                                 v_index_type,
        --                                 CONCAT(SUBSTR(v_src_table_name, 1, v_max_idx_length - LENGTH(v_tmp_str) - 1), 
        --                                        '$', 
        --                                        v_tmp_str
        --                                       ), ' ', 
        --                                 '(', v_index_columns, ')');

        SET v_index_column_def = CONCAT(v_index_column_def, '  ',
                                        v_index_type,
                                        IF(v_index_name <> 'PRIMARY',
                                           v_index_name,
                                           ''
                                          ), ' ', 
                                        '(', v_index_columns, ')');

        -- debug
        IF debug_mode_in THEN
          SELECT v_index_column_def AS "Indexes";
        END IF;  

      END LOOP;  -- for all TABLE Indexes
      -- ================================

      -- close INDEX cursor
      CLOSE src_local_indexes_cur;

    END IF;  -- IF (v_schema_type <> LINK_SCHEMA_TYPE)

    -- Shard Info
    OPEN shard_info_cur;   -- F(v_host_alias)
    FETCH shard_info_cur
     INTO v_shard_schema_name,
          v_shard_table_name;
    CLOSE shard_info_cur;
    
    -- ================================
    -- Create new table
    -- ================================
    IF (v_schema_type = DELTA_SCHEMA_TYPE) THEN

      -- DELTA
      SET is_table_exists = FALSE;
      SELECT TRUE
        INTO is_table_exists
        FROM information_schema.tables
       WHERE table_schema = DELTA_SCHEMA_NAME
         AND table_name   = v_src_table_name;

      IF NOT is_table_exists THEN
        IF (v_src_schema_name <> v_shard_schema_name) OR (v_src_table_name <> v_shard_table_name) THEN
          -- Columns
          SET @sql_stmt = CONCAT('CREATE TABLE ', DELTA_SCHEMA_NAME, '.', v_src_table_name, @LF,
                                 '(', @LF,
                                 v_table_column_def);

          -- Indexes
          IF LENGTH(v_index_column_def) > 1 THEN
            SET @sql_stmt = CONCAT(@sql_stmt, ',', @LF,
                                   v_index_column_def);
          END IF;

          -- Parameters
          SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                                 ')', @LF,
                                 'ENGINE = ''', v_db_engine_type, '''', @LF,
                                 'DEFAULT CHARSET = utf8', @LF,
                                 'COLLATE = utf8_bin');
          IF debug_mode_in THEN
            SELECT CONCAT(@LF, 
                          CAST(@sql_stmt AS CHAR), @LF, 
                          ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
          END IF; 

        END IF;  -- IF (v_src_table_name)
      END IF;  -- IF NOT is_table_exists

    ELSEIF (v_schema_type = LINK_SCHEMA_TYPE) THEN

      -- Create a set of FED tables in LINK schema
      OPEN shard_conn_cur;
      -- ================================
      shard_numbers:
      LOOP
        SET done = FALSE;

        FETCH shard_conn_cur        -- F(v_host_alias, status = 1)
         INTO v_shard_number,       -- !!!
              v_src_conn_str;       -- CONCAT('mysql://', spf.db_user_name, ':', spf.db_user_pwd, '@', spf.host_ip_address, ':', spf.host_port_num)

        IF NOT done THEN
          SET is_table_exists = FALSE;
          SELECT TRUE
            INTO is_table_exists
            FROM information_schema.tables
           WHERE table_schema = LINK_SCHEMA_NAME
             AND table_name = CONCAT(v_host_alias, '_', v_shard_number, '_', v_src_schema_name, '_', v_src_table_name);

          IF NOT is_table_exists THEN
            -- ====================================================
            -- INDEXES = F(SHARD, DB, TABLE)
            -- !!! Attn !!! Not for LINK tables
            -- ====================================================
            SET v_index_column_def  = '';
            -- open different INDEX cursors (information schema = F(DBn)) 
            OPEN src_local_indexes_cur;

            -- ================================
            src_db_indexes:
            LOOP
              SET done = FALSE;

              -- get index (name, unique, columns)
              FETCH src_local_indexes_cur
              INTO v_index_name, v_index_non_unique, v_index_columns;

              IF NOT done THEN
                -- concatenate index rows
                IF LENGTH(v_index_column_def) > 1 THEN
                  SET v_index_column_def  = CONCAT(v_index_column_def, ',', @LF);
                END IF;

                -- Define INDEX Type
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

                SET v_index_column_def = CONCAT(v_index_column_def, '  ',
                                                v_index_type,
                                                CONCAT(SUBSTR(CONCAT(v_host_alias, '_',
                                                                     v_shard_number, '_', 
                                                                     v_src_schema_name, '_', 
                                                                     v_src_table_name
                                                                     ), 1, v_max_idx_length - LENGTH(v_tmp_str) - 1), 
                                                                     '$',
                                                                     v_tmp_str
                                                       ), ' ',
                                                '(', v_index_columns, ')');
                -- Debug
                IF debug_mode_in THEN
                  SELECT v_index_column_def AS "Indexes";
                END IF;  -- debug
              ELSE
                SET done = FALSE;
                LEAVE src_db_indexes;
              END IF;  -- IF-ELSE NOT done

            END LOOP;  -- src_db_indexes
            -- ================================
            -- close INDEX cursor
            CLOSE src_local_indexes_cur;

            -- ========================
            -- Create table
            -- ========================
            -- Columns
            SET @sql_stmt = CONCAT('CREATE TABLE ', LINK_SCHEMA_NAME, '.', v_host_alias, '_', v_shard_number, '_', v_src_schema_name, '_', v_src_table_name, @LF,
                                   '(', @LF,
                                   v_table_column_def);

            -- Indexes
            IF LENGTH(v_index_column_def) > 1 THEN
              SET @sql_stmt = CONCAT(@sql_stmt, ',', @LF,
                                     v_index_column_def);
            END IF;

            -- Parameters
            SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                                   ')', @LF,
                                   'ENGINE = FEDERATED', @LF,
                                   'DEFAULT CHARSET = utf8', @LF,
                                   'COLLATE = utf8_bin', @LF,
                                   'CONNECTION = ','\'',v_src_conn_str,'/',v_src_schema_name,'/',v_src_table_name,'\'' );  -- CHAR(39)

            IF debug_mode_in THEN
              SELECT CONCAT(@LF, 
                            CAST(@sql_stmt AS CHAR), @LF, 
                            ";", @LF) AS debug_sql;
            ELSE
              PREPARE query FROM @sql_stmt;
              EXECUTE query;
              DEALLOCATE PREPARE query;
            END IF;

          END IF;  -- IF NOT is_table_exists
        ELSE
          LEAVE shard_numbers;
        END IF;  

      END LOOP;  -- shard_numbers
      -- ================================
      CLOSE shard_conn_cur;

    ELSE
      -- DB Schema
      SET is_table_exists = FALSE;
      SELECT TRUE
        INTO is_table_exists
        FROM information_schema.tables
       WHERE table_schema = v_src_schema_name
         AND table_name   = v_src_table_name;
      IF NOT is_table_exists THEN

        -- Columns
        SET @sql_stmt = CONCAT('CREATE TABLE ', v_src_schema_name, '.', v_src_table_name, @LF,
                               '(', @LF,
                               v_table_column_def);

        -- Indexes
        IF LENGTH(v_index_column_def) > 1 THEN
          SET @sql_stmt = CONCAT(@sql_stmt, ',', @LF,
                                 v_index_column_def);
        END IF;

        -- Parameters
        SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                               ')', @LF,
                               'ENGINE = ''', v_db_engine_type, '''', @LF,
                               'DEFAULT CHARSET = utf8', @LF,
                               'COLLATE = utf8_bin');

        IF debug_mode_in THEN
          SELECT CONCAT(@LF, 
                        CAST(@sql_stmt AS CHAR), @LF, 
                        ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF; 

      END IF;  -- IF NOT is_table_exists
    END IF;  -- IF-ELSE v_schema_type
    -- ================================
    SET error_code_out = 0;
  END;  -- exec  

  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;

END$$

DELIMITER ;

SELECT 'Procedure ''add_elt_table'' has been created' AS "Info:" FROM dual;
