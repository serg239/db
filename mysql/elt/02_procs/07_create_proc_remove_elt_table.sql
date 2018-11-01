/*
  Version:
    2011.11.12.01
  Script:
    07_create_proc_remove_elt_table.sql
  Description:
    Remove table from a given ELT schema.
  Input:
    schema_type_in     - Schema Type.
                         Values: 
                           * DELTA - Add table to DELTA Schema
                           * STAGE - Add table to STAGE Schema
    src_schema_name_in - Schema Name.
    src_table_name_in  - Table Name.
    debug_mode_in      - Debug Mode.
                         Values:
                           * TRUE  (1) - show SQL statements
                           * FALSE (0) - execute SQL statements
  Output:
    Error Code: 
      * 0   - Success
      * -2: common error
      * -3: wrong schema type (schema_type_in)
      * -4: table has been already created
  Istall:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\07_create_proc_remove_elt_table.sql
  Usage (display SQL only):
    CALL elt.remove_elt_table (@err, 'db2', 'DELTA', 'load_catalog', 'shard_account_list', FALSE);   -- delta   
    CALL elt.remove_elt_table (@err, 'db2', 'STAGE', 'load_catalog', 'shard_account_list', FALSE);   -- staging
    CALL elt.remove_elt_table (@err, 'db2', 'LINK',  'load_catalog', 'shard_account_list', FALSE);   -- link (for all shards)
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.remove_elt_table
$$

CREATE PROCEDURE elt.remove_elt_table
(
  OUT error_code_out      INTEGER,
   IN schema_type_in      VARCHAR(16),   -- local [STAGE|DELTA|LINK]
   IN host_alias_in       VARCHAR(16),   -- Host Alias [db1|db2]
   IN src_schema_name_in  VARCHAR(64),   -- source schema name
   IN src_table_name_in   VARCHAR(64),   -- source table name
   IN debug_mode_in       BOOLEAN
)
BEGIN

  DECLARE DELTA_SCHEMA_TYPE      VARCHAR(16)  DEFAULT 'DELTA';         -- delta schema type
  DECLARE STAGE_SCHEMA_TYPE      VARCHAR(16)  DEFAULT 'STAGE';         -- stage schema type
  DECLARE LINK_SCHEMA_TYPE       VARCHAR(16)  DEFAULT 'LINK';          -- link schema type

  DECLARE DELTA_SCHEMA_NAME      VARCHAR(64) DEFAULT 'db_delta';    -- delta
  DECLARE STAGE_SCHEMA_NAME      VARCHAR(64) DEFAULT 'db_stage';    -- stage
  DECLARE LINK_SCHEMA_NAME       VARCHAR(64) DEFAULT 'db_link';     -- link

  DECLARE v_schema_type          VARCHAR(16);
  DECLARE v_host_alias           VARCHAR(16);

  DECLARE v_src_schema_name      VARCHAR(64) DEFAULT src_schema_name_in;
  DECLARE v_src_table_name       VARCHAR(64) DEFAULT src_table_name_in;

  -- Sharding
  DECLARE v_shard_schema_name    VARCHAR(64);
  DECLARE v_shard_table_name     VARCHAR(64);

  DECLARE v_dst_schema_name      VARCHAR(64);

  DECLARE is_sch_exists          BOOLEAN  DEFAULT FALSE;
  DECLARE is_table_exists        BOOLEAN  DEFAULT FALSE;
  
  DECLARE v_shard_number         VARCHAR(2);    -- Shard Number
  DECLARE v_src_conn_str         VARCHAR(255);  -- Connection String
  
  DECLARE done                   BOOLEAN DEFAULT FALSE;

  DECLARE v_tmp_str              VARCHAR(64);
  
  DECLARE v_max_idx_length       INTEGER DEFAULT 64;


  -- Shard Information
  DECLARE shard_info_cur CURSOR
  FOR
    SELECT DISTINCT shard_schema_name,
           shard_table_name
      FROM elt.shard_profiles   spf
     WHERE host_alias = v_host_alias
       AND status     = 1;              -- active shard

  -- Shard Numbers
  DECLARE shard_num_cur CURSOR
  FOR
    SELECT spf.shard_number   AS src_shard_num
      FROM elt.src_tables             st
        INNER JOIN elt.shard_profiles spf
          ON spf.shard_profile_id = st.shard_profile_id
            AND spf.status = 1
     WHERE spf.host_alias     = v_host_alias
       AND st.src_schema_name = v_src_schema_name
       AND st.src_table_name  = v_src_table_name;


  -- 'NOT FOUND' Handler
  DECLARE CONTINUE HANDLER 
  FOR NOT FOUND 
  SET done = TRUE;

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF = CHAR(10); 

  exec:
  BEGIN

    SET v_schema_type = UPPER(schema_type_in);
    SET v_host_alias  = LOWER(host_alias_in);
    
    --
    IF (v_schema_type <> STAGE_SCHEMA_TYPE) AND
       (v_schema_type <> DELTA_SCHEMA_TYPE) AND
       (v_schema_type <> LINK_SCHEMA_TYPE) THEN
       SET error_code_out = -3;
       LEAVE exec;
    ELSE  
      IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
        SET v_dst_schema_name = STAGE_SCHEMA_NAME;
      ELSEIF (v_schema_type = DELTA_SCHEMA_TYPE) THEN 
        SET v_dst_schema_name = DELTA_SCHEMA_NAME;
      ELSEIF (v_schema_type = LINK_SCHEMA_TYPE) THEN 
        SET v_dst_schema_name = LINK_SCHEMA_NAME;
      END IF;
    END IF;  

    SET error_code_out = -2;
    
    --
    -- Check if local schema exists
    --
    SELECT TRUE 
      INTO is_sch_exists
      FROM information_schema.schemata 
     WHERE schema_name = v_dst_schema_name;

    IF NOT is_sch_exists THEN
      SELECT CONCAT('Schema ''', v_dst_schema_name, ''' does not exist') AS "WARNING" FROM dual;
      SET error_code_out = -3;
      LEAVE exec;
    END IF;  -- IF-ELSE

    --
    -- Check if table exists in local schema
    --
    SELECT TRUE
      INTO is_table_exists
      FROM information_schema.tables
     WHERE table_schema = v_dst_schema_name 
       AND table_name   = src_table_name_in;
     
    IF is_table_exists THEN
    
      -- Shard Info
      OPEN shard_info_cur;   -- F(v_host_alias)
      FETCH shard_info_cur
       INTO v_shard_schema_name,
            v_shard_table_name;
      CLOSE shard_info_cur;
   
      -- ==============================
      -- DROP TABLE
      -- ==============================
      SET @sql_stmt = '';
      SET is_sch_exists = FALSE;

      IF (v_schema_type = DELTA_SCHEMA_TYPE) THEN

        IF (v_src_schema_name <> v_shard_schema_name) AND (v_src_table_name <> v_shard_table_name) THEN
          SET @sql_stmt = CONCAT('DROP TABLE ', DELTA_SCHEMA_NAME, '.', v_src_table_name); 
          IF debug_mode_in THEN
            SELECT CONCAT(@LF, 
                          CAST(@sql_stmt AS CHAR), @LF, 
                          ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
          END IF; 
        END IF;
      ELSEIF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
        IF (v_src_schema_name <> v_shard_schema_name) AND (v_src_table_name <> v_shard_table_name) THEN
          SET @sql_stmt = CONCAT('DROP TABLE ', STAGE_SCHEMA_NAME, '.', v_src_table_name);
          IF debug_mode_in THEN
            SELECT CONCAT(@LF, 
                          CAST(@sql_stmt AS CHAR), @LF, 
                          ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
          END IF; 
        END IF;  
      ELSEIF (v_schema_type = LINK_SCHEMA_TYPE) THEN

        OPEN shard_num_cur;
        -- ================================
        shard_numbers:
        LOOP
          SET done = FALSE;
          FETCH shard_num_cur        -- F(v_host_alias, v_src_schema_name, v_src_table_name)
           INTO v_shard_number;      -- !!!
           IF done THEN
             LEAVE shard_numbers;
           END IF;
          SET is_table_exists = FALSE;
          SELECT TRUE
            INTO is_table_exists
            FROM information_schema.tables
           WHERE table_schema = LINK_SCHEMA_NAME
             AND table_name = CONCAT(v_host_alias, '_', v_shard_number, '_', v_src_schema_name, '_', v_src_table_name);
          IF is_table_exists THEN
            -- Drop table
            SET @sql_stmt = CONCAT('DROP TABLE ', LINK_SCHEMA_NAME, '.', v_host_alias, '_', v_shard_number, '_', v_src_schema_name, '_', v_src_table_name);
            IF debug_mode_in THEN
              SELECT CONCAT(@LF, 
                            CAST(@sql_stmt AS CHAR), @LF, 
                            ";", @LF) AS debug_sql;
            ELSE
              PREPARE query FROM @sql_stmt;
              EXECUTE query;
              DEALLOCATE PREPARE query;
            END IF;
          END IF;  -- IF is_table_exists
        END LOOP;  -- shard_numbers
        -- ================================
        CLOSE shard_num_cur;
      
      END IF;  -- IF-ELSE (v_schema_type)
      -- 
      -- Remove record(s) from src_tables (for all shards)
      -- 
      DELETE FROM elt.src_tables 
       WHERE src_schema_name = src_schema_name_in
         AND src_table_name  = src_table_name_in;
      COMMIT;
    ELSE
      -- table does not exists
      SELECT CONCAT('Table ''', src_schema_name_in, '.', src_table_name_in, ''' does not exist') AS "WARNING" FROM dual;
      SET error_code_out = -4;
      LEAVE exec;
    END IF;  -- IF-ELSE
    SET error_code_out = 0;
  END;  -- exec  
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END
$$

DELIMITER ;

SELECT 'Procedure ''remove_elt_table'' has been created' AS "Info:" FROM dual;
