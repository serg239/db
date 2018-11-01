/*
  Version:
    2011.11.16.01
  Script:
    01_create_proc_create_tables_from_src.sql
  Description:
    Create tables described in src_tables in a given schema.
    Table name: '<dst_schema_name>.<src_table_name>'
  Input:
    * dst_schema_name   - DST schema name.
    * db_engine_type    - DST table's DB engine type.  
    * log_only          - Log Tables Only flag.
    * add_indexes       - Add Indexes flag.
    * debug_mode        - Debug Mode.
                          Values:
                            * TRUE  (1) - show SQL statements
                            * FALSE (0) - execute SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\01_create_proc_create_tables_from_src.sql
  Usage:
    CALL elt.create_tables_from_src (@err_num, 'log_dups', 'MyISAM', TRUE, FALSE, TRUE); -- MyISAM, LOG only, NO Indexes
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.create_tables_from_src
$$

CREATE PROCEDURE elt.create_tables_from_src
(
  OUT error_code_out      INTEGER,
   IN dst_schema_name_in  VARCHAR(64),
   IN db_engine_type_in   VARCHAR(64), 
   IN log_only_in         BOOLEAN,
   IN add_indexes_in      BOOLEAN,
   IN debug_mode_in       BOOLEAN
)
BEGIN

  -- Constants
  DECLARE DB1_HOST_ALIAS         VARCHAR(16) DEFAULT 'db1';
  DECLARE DB2_HOST_ALIAS         VARCHAR(16) DEFAULT 'db2';

  -- Input parameters
  DECLARE v_dst_schema_name      VARCHAR(64) DEFAULT dst_schema_name_in;
  DECLARE v_db_engine_type       VARCHAR(64) DEFAULT db_engine_type_in;
  DECLARE v_log_only             BOOLEAN     DEFAULT log_only_in;
  DECLARE v_add_indexes          BOOLEAN     DEFAULT add_indexes_in;
  
  DECLARE v_host_alias           VARCHAR(16);  -- [db1|db2]
  DECLARE v_src_schema_name      VARCHAR(64);
  DECLARE v_src_table_name       VARCHAR(64);

  DECLARE v_column_name          VARCHAR(64);
  DECLARE v_column_type          TEXT;
  DECLARE v_is_column_nullable   VARCHAR(3);
  DECLARE v_column_default       TEXT;
  DECLARE v_max_col_name_size    TINYINT;
  DECLARE v_table_column_def     TEXT;

  DECLARE v_index_name           VARCHAR(255);
  DECLARE v_index_non_unique     SMALLINT;
  DECLARE v_index_columns        VARCHAR(255);
  DECLARE v_index_column_def     TEXT;
  DECLARE v_index_type           VARCHAR(64);
  DECLARE v_tmp_str              VARCHAR(64);

  DECLARE is_sch_exists          BOOLEAN DEFAULT FALSE;
  DECLARE done                   BOOLEAN DEFAULT FALSE;

  -- ==================================
  -- SRC ALL Tables
  -- ==================================
  DECLARE src_all_tables_cur CURSOR
  FOR
    SELECT DISTINCT st.host_alias,
           st.src_schema_name,
           st.src_table_name
      FROM elt.src_tables              st
        INNER JOIN elt.shard_profiles  spf
          USING(shard_profile_id)
     WHERE st.src_table_load_status  = 1     -- active SRC tables
       AND st.src_table_valid_status = 1     -- valid SRC tables
       AND st.src_table_name <> IFNULL(spf.shard_table_name, '');

  -- ==================================
  -- SRC LOG Tables
  -- ==================================
  DECLARE src_log_tables_cur CURSOR
  FOR
    SELECT DISTINCT st.host_alias,
           st.src_schema_name,
           st.src_table_name
      FROM elt.src_tables              st
        INNER JOIN elt.shard_profiles  spf
          USING(shard_profile_id)
     WHERE st.src_table_load_status  = 1     -- active SRC tables
       AND st.src_table_valid_status = 1     -- valid SRC tables
       AND st.src_table_name <> IFNULL(spf.shard_table_name, '')
       AND st.src_table_type = 'LOG';

  -- ==================================
  -- Columns from SRC DB1 tables
  -- ==================================
  DECLARE src_db1_columns_cur CURSOR
  FOR
    SELECT CONCAT(CHAR(96),column_name,CHAR(96)) AS column_name,
           column_type,
           is_nullable,
           column_default,
           (SELECT MAX(LENGTH(column_name))
              FROM elt.db1_information_schema_columns
             WHERE table_schema = v_src_schema_name
               AND table_name   = v_src_table_name
            ) + 2  AS max_col_name_size
      FROM elt.db1_information_schema_columns
     WHERE table_schema = v_src_schema_name
       AND table_name   = v_src_table_name
     GROUP BY column_name, column_type, is_nullable, column_default
     ORDER BY ordinal_position;

  -- ==================================
  -- Columns from SRC DB2 tables
  -- ==================================
  DECLARE src_db2_columns_cur CURSOR
  FOR
    SELECT CONCAT(CHAR(96),column_name,CHAR(96)) AS column_name,
           column_type,
           is_nullable,
           column_default,
           (SELECT MAX(LENGTH(column_name))
              FROM elt.db2_information_schema_columns
             WHERE table_schema = v_src_schema_name
               AND table_name   = v_src_table_name
            ) + 2  AS max_col_name_size
      FROM elt.db2_information_schema_columns
     WHERE table_schema = v_src_schema_name
       AND table_name   = v_src_table_name
     GROUP BY column_name, column_type, is_nullable, column_default
     ORDER BY ordinal_position;

  -- ==================================
  -- Indexes from SRC DB1 tables
  -- ==================================
  DECLARE src_db1_indexes_cur CURSOR 
  FOR
    SELECT index_name,
           non_unique,
           GROUP_CONCAT(CONCAT(CHAR(96),column_name,CHAR(96)) ORDER BY seq_in_index SEPARATOR ', ')
      FROM elt.db1_information_schema_indexes
     WHERE index_schema = v_src_schema_name
       AND table_name   = v_src_table_name
    GROUP BY 1, 2;

  -- ==================================
  -- Indexes from DB2 tables
  -- ==================================
  DECLARE src_db2_indexes_cur CURSOR 
  FOR
    SELECT index_name,
           non_unique,
           GROUP_CONCAT(CONCAT(CHAR(96),column_name,CHAR(96)) ORDER BY seq_in_index SEPARATOR ', ')
      FROM elt.db2_information_schema_indexes
     WHERE index_schema = v_src_schema_name
       AND table_name   = v_src_table_name
    GROUP BY 1, 2;

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
    
    -- Check input parameters
    IF v_db_engine_type IS NULL THEN
      SET error_code_out = -3;
      LEAVE exec; 
    END IF;
    
    -- Check if DST schema exists
    SET is_sch_exists = FALSE; 
    SELECT TRUE
      INTO is_sch_exists
      FROM information_schema.schemata 
     WHERE schema_name = v_dst_schema_name;
    IF (NOT is_sch_exists) THEN
      SET error_code_out = -4;
      LEAVE exec;
    END IF;
    
    -- LOG/ALL SRC tables
    IF v_log_only THEN
      OPEN src_log_tables_cur;
    ELSE
      OPEN src_all_tables_cur;
    END IF;  

    -- ==================================
    -- Loop for all elt.src_tables having status = 1
    -- ==================================
    src_tables:
    LOOP
      SET error_code_out = -2;
      SET done = FALSE;
      IF v_log_only THEN
        FETCH src_log_tables_cur
        INTO v_host_alias,         -- [db1|db2]
             v_src_schema_name,    -- schema
             v_src_table_name;     -- log table only 
      ELSE
        FETCH src_all_tables_cur
        INTO v_host_alias,         -- [db1|db2]
             v_src_schema_name,    -- schema
             v_src_table_name;     -- any table 
      END IF;
      IF done THEN
        SET error_code_out = 0;
        LEAVE src_tables;
      END IF;
      IF (v_src_schema_name IS NULL) OR (v_src_table_name IS NULL) THEN
        SELECT "Couldn't get information about SRC tables. Check if SRC tables have been validated." AS "ERROR" FROM dual;
        SET error_code_out = -4;
        LEAVE src_tables;
      END IF;
      -- ==============================
      -- COLUMNS = F(v_src_schema_name, v_src_table_name) -> v_table_column_def
      -- ==============================
      SET v_table_column_def = '';
      -- open different COLUMN cursors (information schema = F(DBn)) 
      IF (v_host_alias = DB1_HOST_ALIAS) THEN
        OPEN src_db1_columns_cur;                        -- F(v_src_schema_name, v_src_table_name)
      ELSE
        OPEN src_db2_columns_cur;                        -- F(v_src_schema_name, v_src_table_name)
      END IF;  
      -- ==============================
      src_db_columns:
      LOOP
        SET error_code_out = -2;
        SET done = FALSE;
        IF (v_host_alias = DB1_HOST_ALIAS) THEN
          FETCH src_db1_columns_cur
          INTO v_column_name, v_column_type, v_is_column_nullable, v_column_default, v_max_col_name_size;
        ELSE
          FETCH src_db2_columns_cur
          INTO v_column_name, v_column_type, v_is_column_nullable, v_column_default, v_max_col_name_size;
        END IF;  
        -- check end of Loop (FETCH)
        IF done THEN
          SET error_code_out = 0;
          SET done = FALSE;
          LEAVE src_db_columns;
        END IF;
        --
        IF (v_table_column_def <> '') THEN
          SET v_table_column_def = CONCAT(v_table_column_def, ',', @LF);   -- add comma after the last column_def
        ELSE  
          SET v_table_column_def = '  ';
        END IF;
        --
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
        SET error_code_out = 0;
      END LOOP;  -- for all TABLE Columns (src_dbX_columns_cur)
      -- ==============================
      -- close COLUMN cursor
      IF (v_host_alias = DB1_HOST_ALIAS) THEN
        CLOSE src_db1_columns_cur;
      ELSE
        CLOSE src_db2_columns_cur;
      END IF;

      -- ==============================
      -- INDEXES = F(src_schema_name_in, src_table_name_in) -> v_index_column_def 
      -- ==============================
      SET v_index_column_def = '';

      IF v_add_indexes THEN
        -- open different INDEX cursors (information schema = F(DBn)) 
        IF (v_host_alias = DB1_HOST_ALIAS) THEN
          OPEN src_db1_indexes_cur;              -- F(v_src_schema_name, v_src_table_name)
        ELSE
          OPEN src_db2_indexes_cur;              -- F(v_src_schema_name, v_src_table_name)
        END IF;  

        -- ==============================
        src_db_indexes:
        LOOP
          SET error_code_out = -2;
          SET done = FALSE;
          -- get index (name, unique, columns)
          IF (v_host_alias = DB1_HOST_ALIAS) THEN
            FETCH src_db1_indexes_cur
            INTO v_index_name, v_index_non_unique, v_index_columns;
          ELSE
            FETCH src_db2_indexes_cur
            INTO v_index_name, v_index_non_unique, v_index_columns;
          END IF;  
          IF done THEN
            SET error_code_out = 0;
            SET done = FALSE;
            LEAVE src_db_indexes;
          END IF;
          --
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
          SET v_index_column_def = CONCAT(v_index_column_def, '  ',
                                          v_index_type,
                                          IF(v_index_name <> 'PRIMARY',
                                             v_index_name,
                                             ''
                                            ), ' ', 
                                          '(', v_index_columns, ')');
          SET error_code_out = 0;
        END LOOP;  -- for all TABLE Indexes (src_dbX_index_cur)
        -- ==============================
        -- close INDEX cursor
        IF (v_host_alias = DB1_HOST_ALIAS) THEN
          CLOSE src_db1_indexes_cur;
        ELSE
          CLOSE src_db2_indexes_cur;
        END IF;
      END IF;  -- IF v_add_indexes  
      -- ==============================
      -- CREATE TABLE
      -- ==============================
      SET error_code_out = -2;
      SET @sql_stmt = CONCAT('CREATE TABLE IF NOT EXISTS ', v_dst_schema_name, '.', v_src_table_name, @LF,     -- v_src_schema_name, '_', 
                             '(', @LF, v_table_column_def
                            ); 
      IF v_add_indexes THEN 
        SET @sql_stmt = CONCAT(@sql_stmt, ',', @LF,
                               v_index_column_def
                              );
      END IF;
      SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                             ')', @LF,
                             'ENGINE = ', v_db_engine_type, @LF,
                             'DEFAULT CHARSET = utf8 ', @LF,
                             'COLLATE = utf8_bin ');
      IF debug_mode_in THEN
        SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
        -- 
        COMMIT;
        --
        SET error_code_out = 0;
      END IF;
    END LOOP;  -- for all TABLEs (src_db_tables)
    -- ================================
    IF v_log_only THEN
      CLOSE src_log_tables_cur;
    ELSE
      CLOSE src_all_tables_cur;
    END IF;
  END;  -- exec
  IF debug_mode_in THEN
    SET error_code_out = 0;
  END IF;
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END
$$

DELIMITER ;

SELECT '====> Procedure ''create_src_tables'' has been created' AS "Info:" FROM dual;
