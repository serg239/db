/*
  Version:
    2011.12.11.01
  Script:
    20_create_proc_load_elt_data.sql
  Description:
    Load ELT data into STAGE or DELTA schemas.
  Input:
    * schema_type - Destination Schema name. Values: [STAGE | DELTA]  
    * debug_mode      - Debug Mode.
                        Values:
                          * FALSE (0) - execute SQL statements
                          * TRUE  (1) - show SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\20_create_proc_load_elt_data.sql
  Usage:   
    CALL elt.load_log_data (@err, 'DELTA', TRUE);    -- display SQL only
    CALL elt.load_log_data (@err, 'DELTA', FALSE);   -- execute SQL
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.load_elt_data$$

CREATE PROCEDURE elt.load_elt_data
( 
  OUT error_code_out  INTEGER,
   IN schema_type_in  VARCHAR(8),   -- [STAGE|DELTA]
   IN debug_mode_in   BOOLEAN
)
BEGIN

  DECLARE DB1_HOST_ALIAS              VARCHAR(16) DEFAULT 'db1';
  DECLARE DB2_HOST_ALIAS              VARCHAR(16) DEFAULT 'db2';

  DECLARE LINK_SCHEMA_TYPE            VARCHAR(8)  DEFAULT 'LINK';        -- link schema type
  DECLARE STAGE_SCHEMA_TYPE           VARCHAR(8)  DEFAULT 'STAGE';       -- stage schema type
  DECLARE DELTA_SCHEMA_TYPE           VARCHAR(8)  DEFAULT 'DELTA';       -- delta schema type
  
  DECLARE MASTER_TABLE_TYPE           VARCHAR(8)  DEFAULT 'MASTER';      -- MASTER table type

  DECLARE PROC_SCHEMA_NAME            VARCHAR(64) DEFAULT 'elt';         -- control schema
  DECLARE LINK_SCHEMA_NAME            VARCHAR(64) DEFAULT 'db_link';     -- link
  DECLARE STAGE_SCHEMA_NAME           VARCHAR(64) DEFAULT 'db_stage';    -- stage
  DECLARE DELTA_SCHEMA_NAME           VARCHAR(64) DEFAULT 'db_delta';    -- delta
  
  DECLARE v_schema_type               VARCHAR(16);
  DECLARE v_dst_schema_name           VARCHAR(64);                         -- destination schema [db_stage | db_delta]

  DECLARE v_db1_shards_per_host       INTEGER; 
  DECLARE v_db2_shards_per_host       INTEGER; 

  DECLARE v_db1_shard_schema_name     VARCHAR(64);
  DECLARE v_db1_shard_table_name      VARCHAR(64);
  DECLARE v_db1_shard_table_alias     VARCHAR(8);
  DECLARE v_db1_shard_column_name     VARCHAR(64);

  DECLARE v_db2_shard_schema_name     VARCHAR(64);
  DECLARE v_db2_shard_table_name      VARCHAR(64);
  DECLARE v_db2_shard_table_alias     VARCHAR(8);
  DECLARE v_db2_shard_column_name     VARCHAR(64);

  DECLARE v_control_download_id       INTEGER;
  DECLARE v_host_alias                VARCHAR(16);   -- [db1|db2]
  DECLARE v_shard_number              CHAR(2);       -- [01|02|...]
  DECLARE v_src_conn_str              VARCHAR(256);
  DECLARE v_src_schema_name           VARCHAR(64);
  DECLARE v_src_table_name            VARCHAR(64);
  DECLARE v_src_table_alias           VARCHAR(8);
  DECLARE v_src_table_type            VARCHAR(8);
  DECLARE v_control_type              VARCHAR(8);
  DECLARE v_control_start_dtm         TIMESTAMP;
  DECLARE v_control_end_dtm           TIMESTAMP;
  DECLARE v_dtm_column_name           VARCHAR(64);    -- dtm_column_name  Ex.: modified_dtm, log_created_dtm
  DECLARE v_sharding_column_name      VARCHAR(64);    -- shard_column_name Ex.: account_id, owner_account_id
  DECLARE v_proc_pk_column_name       VARCHAR(64);
  DECLARE v_proc_block_size           INTEGER;
  DECLARE v_where_clause              VARCHAR(2000);
  DECLARE v_order_by_clause           VARCHAR(250);

  DECLARE v_tmp_link_tbl_name         VARCHAR(64);    -- federated, PK IDs
  DECLARE v_tmp_pk_tbl_name           VARCHAR(64);    -- local, all PK IDs
  DECLARE v_tmp_block_pk_tbl_name     VARCHAR(64);    -- local, all PK IDs of the Block

  DECLARE v_block_offset_num          INTEGER  DEFAULT 0;
  DECLARE v_num_blocks                INTEGER  DEFAULT 0;  -- number of blocks
  
  DECLARE v_proc_rows                 INTEGER  DEFAULT 0;  -- number of processed rows
  DECLARE v_proc_duration             INTEGER  DEFAULT 0; 

  DECLARE v_dtm_cond_clause           VARCHAR(1000);

  DECLARE v_insert_columns            VARCHAR(4000);   -- INSERT INTO ()
  DECLARE v_select_columns            VARCHAR(4000);   -- SELECT ...
  DECLARE v_dupl_update_columns       VARCHAR(4000);   -- ON DUPLICATE KEY ... UPDATE

  DECLARE v_download_timing_start     TIMESTAMP;
  DECLARE v_download_timing_end       TIMESTAMP;

  DECLARE is_table_exists             BOOLEAN DEFAULT FALSE;  -- 0
  DECLARE v_table_name                VARCHAR(64);

  DECLARE done                        BOOLEAN DEFAULT FALSE;

  --
  -- Shard Information - 1 record per host_alias
  --
  DECLARE shard_info_cur CURSOR
  FOR
    SELECT spf.shard_schema_name,
           spf.shard_table_name,
           spf.shard_table_alias,
           spf.shard_column_name
      FROM elt.shard_profiles   spf
     WHERE spf.host_alias = v_host_alias   -- host
       AND spf.status     = 1              -- active shard
     LIMIT 1;             
  --
  -- SRC tables
  --
  DECLARE main_proc_tables_cur CURSOR
  FOR
  SELECT cd.control_download_id,
         st.host_alias,                -- [db1|db2]
         st.shard_number,              -- [01|02|...]
         CONCAT('mysql://', spf.db_user_name, ':', spf.db_user_pwd, '@', spf.host_ip_address, ':', spf.host_port_num) AS src_conn_str,  -- for temp table
         st.src_schema_name,
         st.src_table_name,
         st.src_table_alias,
         st.src_table_type,            -- [MASTER|LOG]
         cd.control_type,              -- [STAGE|DELTA]
         cd.control_start_dtm,         -- BETWEEN start_date 
         cd.control_end_dtm,           --     AND end_date
         st.proc_block_size,
         cd.where_clause,
         cd.order_by_clause
    FROM elt.control_downloads        cd
      INNER JOIN elt.src_tables       st
        ON cd.src_table_id = st.src_table_id
      INNER JOIN elt.shard_profiles  spf
        ON st.shard_profile_id = spf.shard_profile_id
          AND spf.status = 1                             -- active shard
   WHERE cd.download_status = 0                          -- not processed yet
   ORDER BY st.src_table_id
--   ORDER BY st.src_table_type DESC, st.src_table_id ASC  -- 'MASTER' and 'LOG' after that
  ;

  DECLARE detail_tables_cur CURSOR
  FOR
  SELECT st.dtm_column_name,           -- Ex.: modified_dtm, log_created_dtm
         st.sharding_column_name,      -- Ex.: account_id, owner_account_id
         st.proc_pk_column_name       -- PK on MASTER or FK to MASTER
    FROM elt.src_tables  st
   WHERE st.host_alias      = v_host_alias
     AND st.shard_number    = v_shard_number
     AND st.src_schema_name = v_src_schema_name
     AND st.src_table_name  = v_src_table_name;
      
  -- Handlers
  DECLARE CONTINUE HANDLER      -- handle cursor exhaustion
  FOR NOT FOUND 
  SET done = TRUE;              -- mark the loop control variable
  
--  DECLARE EXIT HANDLER          -- handle other errors
--  FOR SQLEXCEPTION            
--  CLOSE main_proc_tables_cur;   -- free resources before exit
  
--  SET @old_foreign_key_checks = (SELECT @@FOREIGN_KEY_CHECKS);
--  SET @@FOREIGN_KEY_CHECKS = 0;
  
  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF       = CHAR(10); 
  SET @sql_stmt = '';

  -- ================================ 
  exec:
  BEGIN
  
    SET v_schema_type = UPPER(schema_type_in);
    
    IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
      SET v_dst_schema_name = STAGE_SCHEMA_NAME;
    ELSEIF (v_schema_type = DELTA_SCHEMA_TYPE) THEN  
      SET v_dst_schema_name = DELTA_SCHEMA_NAME;
    ELSE
      SET error_code_out = -3;
      LEAVE exec;
    END IF;  
      
    -- Disable Logs
--  Note: only GLOBAL available, required SUPER privileges 
--  SET @old_general_log    = (SELECT @@GLOBAL.GENERAL_LOG);
--  SET @old_slow_query_log = (SELECT @@GLOBAL.SLOW_QUERY_LOG);
--  SET @@GLOBAL.GENERAL_LOG    = 'OFF';   -- SET GLOBAL GENERAL_LOG    = 0;
--  SET @@GLOBAL.SLOW_QUERY_LOG = 'OFF';   -- SET GLOBAL SLOW_QUERY_LOG = 0;
    
    -- ================================
    -- Get Shards for Host 1 -> v_db1_shards_per_host, names 
    -- ================================
    SET v_host_alias = DB1_HOST_ALIAS;
    SELECT COUNT(*)
      INTO v_db1_shards_per_host
      FROM elt.shard_profiles
     WHERE host_alias = v_host_alias
       AND status = 1;  
    IF (v_db1_shards_per_host > 0) THEN
      OPEN shard_info_cur;
      FETCH shard_info_cur                  -- F(v_host_alias), LIMIT 1
       INTO v_db1_shard_schema_name,
            v_db1_shard_table_name,
            v_db1_shard_table_alias,
            v_db1_shard_column_name;
      CLOSE shard_info_cur;
      IF (v_db1_shard_table_name IS NOT NULL) THEN
        -- check/create FED table(s) in LINK schema for sharded tables
        CALL elt.add_elt_table (@err, LINK_SCHEMA_TYPE, v_host_alias, v_db1_shard_schema_name, v_db1_shard_table_name, 'FEDERATED', FALSE);
      END IF;  
    ELSE
      SET error_code_out = -4;
      LEAVE exec;
    END IF;
       
    -- ================================
    -- Get Shards for Host 2 -> v_db2_shards_per_host, names
    -- ================================
    SET v_host_alias = DB2_HOST_ALIAS;
    SELECT COUNT(*)
      INTO v_db2_shards_per_host
      FROM elt.shard_profiles
     WHERE host_alias = v_host_alias
       AND status = 1;  
    IF (v_db2_shards_per_host > 0) THEN
      OPEN shard_info_cur;
      FETCH shard_info_cur                 -- F(v_host_alias), LIMIT 1
       INTO v_db2_shard_schema_name,
            v_db2_shard_table_name,
            v_db2_shard_table_alias,
            v_db2_shard_column_name;
      CLOSE shard_info_cur;
      IF (v_db2_shard_table_name IS NOT NULL) THEN
        -- check/create FED table(s) in LINK schema for sharded tables
        CALL elt.add_elt_table (@err, LINK_SCHEMA_TYPE, v_host_alias, v_db2_shard_schema_name, v_db2_shard_table_name, 'FEDERATED', FALSE);
      END IF;  
    ELSE
      SET error_code_out = -5;
      LEAVE exec;
    END IF;
    
    SET error_code_out = -2;

    OPEN main_proc_tables_cur;

    -- ================================
    -- LOOP for All Tables
    -- ================================
    main_proc_tables:
    LOOP

      SET done = FALSE;

      FETCH main_proc_tables_cur
        INTO v_control_download_id,
             v_host_alias,                 -- [db1|db2]
             v_shard_number,               -- [01|02|...]  
             v_src_conn_str,
             v_src_schema_name,
             v_src_table_name,
             v_src_table_alias,
             v_src_table_type,             -- [MASTER|LOG]
             v_control_type,               -- [STAGE|DELTA]
             v_control_start_dtm,          -- BETWEEN start_date
             v_control_end_dtm,            --     AND end_date 
             v_proc_block_size, 
             v_where_clause,
             v_order_by_clause;

      IF done THEN
        LEAVE main_proc_tables;
      END IF;

      -- ==============================
      -- (Re)Create LINK table(s) for current shard
      -- ==============================
      -- 1. DROP LINK table 
      CALL elt.drop_elt_table (@err_num, LINK_SCHEMA_TYPE, v_host_alias, v_shard_number, v_src_schema_name, v_src_table_name, debug_mode_in);

      -- 2. CREATE LINK table 
      CALL elt.create_elt_table (@err_num, LINK_SCHEMA_TYPE, v_host_alias, v_shard_number, v_src_schema_name, v_src_table_name, debug_mode_in);
      -- ==============================
      
      -- ==============================
      -- Check/add new columns for table (compare with LINK table) 
      -- Note: DTM, SHARDING, and PROC_PK fields could be changed in src_tables
      -- ==============================
      -- CALL elt.check_modify_columns (@err_num, v_host_alias, v_src_schema_name, v_src_table_name, debug_mode_in);
      -- ==============================

      -- ==============================
      -- Drop/add new indexes to STAGE or/and DELTA table (getting from LINK table)
      -- ==============================
      -- CALL elt.check_modify_indexes (@err_num, v_host_alias, v_src_schema_name, v_src_table_name, debug_mode_in);
      -- ==============================
      
      SET done = FALSE;
      
      OPEN detail_tables_cur;             -- F(v_host_alias, v_shard_number, v_src_schema_name, v_src_table_name)
      FETCH detail_tables_cur
       INTO v_dtm_column_name,            -- [modified_dtm|log_created_dtm|last_mod_time]
            v_sharding_column_name,       -- [account_id|owner_account_id]
            v_proc_pk_column_name;        -- [PK (on MASTER) | FK (to master table on LOG)]
      CLOSE detail_tables_cur;
      
      -- ==================================================
      -- 1. DTM
      --    Prepare the Date Range statement
      --    Date Range: control_downloads.control_start_dtm ... control_downloads.control_end_dtm
      -- ================================
      -- Clear the Filters
      SET v_dtm_cond_clause = '';
      --
      IF (v_dtm_column_name IS NOT NULL) THEN
        SET v_dtm_cond_clause = CONCAT(v_src_table_alias, '.', v_dtm_column_name, ' BETWEEN \'', v_control_start_dtm, '\' AND \'', v_control_end_dtm, '\'');
        IF (v_where_clause IS NOT NULL) THEN
          -- Add v_where_clause AND v_dtm_cond_clause
          SET v_dtm_cond_clause = CONCAT('WHERE ', v_where_clause, @LF,
                                         '  AND ', v_dtm_cond_clause);
        ELSE
          -- Add v_dtm_cond_clause
          SET v_dtm_cond_clause = CONCAT('WHERE ', v_dtm_cond_clause);
        END IF;
      ELSE
        IF (v_where_clause IS NOT NULL) THEN
          -- Add v_where_clause
          SET v_dtm_cond_clause = CONCAT('WHERE ', v_where_clause);
        END IF;
      END IF;

      -- ================================
      -- Get list of COLUMNS for INSERT INTO ... () and FROM ... () clauses
      -- ================================
      IF (v_host_alias = DB1_HOST_ALIAS) THEN
        --
        -- Get list of DB1 COLUMNS for INSERT INTO ... () clause
        --
        SELECT GROUP_CONCAT(' ', column_name),
               GROUP_CONCAT(@LF, '       ', v_src_table_alias, ".", column_name) 
          INTO v_insert_columns,
               v_select_columns
          FROM information_schema.columns                     -- changed to Local IS
         WHERE table_schema = v_src_schema_name 
           AND table_name   = v_src_table_name;

        -- v_control_type is defined in control_downloads table for current download
        IF (v_control_type = DELTA_SCHEMA_TYPE) THEN
          -- DELTA: Get list of DB1 COLUMNS for ON DUPLICATE KEY ... UPDATE clause
          SELECT GROUP_CONCAT(@LF, '  ', column_name, ' = ', v_src_table_alias, '.', column_name)
            INTO v_dupl_update_columns
            FROM information_schema.columns                   -- changed to Local IS
           WHERE table_schema = v_src_schema_name 
             AND table_name   = v_src_table_name
             AND column_key  != 'PRI';
        END IF;
      ELSEIF (v_host_alias = DB2_HOST_ALIAS) THEN
        --
        -- Get list of DB2 COLUMNS for INSERT INTO ... () clause
        --
        SELECT GROUP_CONCAT(' ', column_name),
               GROUP_CONCAT(@LF, '       ', v_src_table_alias, ".", column_name) 
          INTO v_insert_columns,
               v_select_columns
          FROM information_schema.columns                     -- changed to Local IS
         WHERE table_schema = v_src_schema_name 
           AND table_name   = v_src_table_name;   
        -- v_control_type is defined in control_downloads table for current download
        IF (v_control_type = DELTA_SCHEMA_TYPE) THEN
          -- DELTA: Get list of DB2 COLUMNS for ON DUPLICATE KEY ... UPDATE clause
          SELECT GROUP_CONCAT(@LF, '  ', column_name, ' = ', v_src_table_alias, '.', column_name)
            INTO v_dupl_update_columns
            FROM information_schema.columns                  -- changed to Local IS 
           WHERE table_schema = v_src_schema_name 
             AND table_name   = v_src_table_name
             AND column_key  != 'PRI';
        END IF;
      END IF;

      --
      -- Process start time
      --
      SET v_download_timing_start = CURRENT_TIMESTAMP();
      --
      -- STAGE or DELTA: Truncate DST Table
      --
      SET @sql_stmt = CONCAT('TRUNCATE TABLE ', v_dst_schema_name, '.', v_src_table_name);
      IF debug_mode_in THEN
        SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF;
      --
      -- STAGE or DELTA: Disable KEYs on DST table
      --
      SET @sql_stmt = CONCAT('ALTER TABLE ', v_dst_schema_name, '.', v_src_table_name, ' DISABLE KEYS');
      IF debug_mode_in THEN
        SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF; 
      -- Number of the processed rows
      SET v_proc_rows = 0;

      -- ==================================================
      -- To chank or not to chunk?
      -- ==================================================
      IF (v_proc_block_size > 0) THEN
        --
        -- Get Index Name on [MASTER] PK of LINK table (LOG => on FK to MASTER table) 
        --
        SET @v_pk_index_name = NULL;
        IF v_src_table_type = 'LOG' THEN
          SET @sql_stmt = CONCAT('SELECT DISTINCT index_name ', @LF, 
                                 '  INTO @v_pk_index_name', @LF,                         -- @v_pk_index_name
                                 '  FROM information_schema.statistics', @LF,
                                 ' WHERE index_schema = ''', LINK_SCHEMA_NAME, '''', @LF,
                                 '   AND table_name   = ''', v_host_alias, '_', v_shard_number, '_', v_src_schema_name, '_', v_src_table_name, '''', @LF,
                                 '   AND index_name LIKE ''%$', v_proc_pk_column_name, '%''');    -- start from PK or FK to MASTER table
        ELSE
          SET @v_pk_index_name = 'PRIMARY';
        END IF;
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF;
        --
        -- Create FEDEARATED Temporary table for MASTER table's (PK, DTM)
        --
        SELECT CONCAT("tmp_link_pk_ids$", CAST(FLOOR(RAND() * 99999999999999) AS CHAR)) INTO v_tmp_link_tbl_name;
        SET @sql_stmt = CONCAT('CREATE TABLE IF NOT EXISTS ', LINK_SCHEMA_NAME, '.', v_tmp_link_tbl_name, @LF,
                               '(', @LF,
                               v_proc_pk_column_name, ' BIGINT NOT NULL,', @LF,
                               v_dtm_column_name, '    TIMESTAMP NOT NULL', @LF,
                               ')', @LF,
                               'ENGINE = FEDERATED', @LF,
                               'CONNECTION = ','\'',v_src_conn_str,'/',v_src_schema_name,'/',v_src_table_name,'\''
                              );
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF;
        --
        -- Create LOCAL PK IDs Table (if Log table - MASTER PK IDs)
        --
        SET v_tmp_pk_tbl_name = REPLACE(v_tmp_link_tbl_name, 'tmp_link_pk_ids', 'tmp_pk_ids');
        SET @sql_stmt = CONCAT('CREATE TABLE IF NOT EXISTS ', PROC_SCHEMA_NAME, '.', v_tmp_pk_tbl_name, @LF,
                               '(', @LF,
                               'pk_id  BIGINT NOT NULL,', @LF,
                               'PRIMARY KEY (pk_id)', @LF,         -- index
--                               'modified_dtm TIMESTAMP NOT NULL', @LF,
                               ')', @LF,
                               'ENGINE = InnoDB'
                              );
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF;
        --
        -- Insert Block (Offset) of MASTER Table PK IDs from LINK to TEMP table
        --
        IF (v_src_table_type = MASTER_TABLE_TYPE) THEN 
          -- PK is unique
          SET @sql_stmt = CONCAT('INSERT INTO ', PROC_SCHEMA_NAME, '.', v_tmp_pk_tbl_name, ' (pk_id) ', @LF,
                                 'SELECT tmp.', v_proc_pk_column_name, ' AS pk_id', @LF,
                                 '  FROM ', LINK_SCHEMA_NAME, '.', v_tmp_link_tbl_name, ' tmp');
        ELSE
          SET @sql_stmt = CONCAT('INSERT INTO ', PROC_SCHEMA_NAME, '.', v_tmp_pk_tbl_name, ' (pk_id) ', @LF,
                                 'SELECT DISTINCT tmp.', v_proc_pk_column_name, ' AS pk_id', @LF,
                                 '  FROM ', LINK_SCHEMA_NAME, '.', v_tmp_link_tbl_name, ' tmp');
        END IF;
        --
        -- Do NOT add JOIN to Accounts-per-Shard table because this loop is per Shard
        --
        -- IF (v_sharding_column_name IS NOT NULL) THEN
        --   SET @sql_stmt = CONCAT(@sql_stmt, @LF,
        --                          '    INNER JOIN ', LINK_SCHEMA_NAME, '.', v_host_alias, '_', v_shard_number, '_', v_db2_shard_schema_name, '_', v_db2_shard_table_name, ' ', v_db2_shard_table_alias, 
        --                          '      ON ', v_src_table_alias, '.', v_sharding_column_name, ' = ', v_db2_shard_table_alias, '.', v_db2_shard_column_name
        --                          );
        -- END IF;
        --
        -- Apply Modified DTM Filter on LINK TMP table
        --
        -- Ex.: v_dtm_cond_clause = CONCAT(v_src_table_alias, '.', v_dtm_column_name, ' BETWEEN \'', v_control_start_dtm, '\' AND \'', v_control_end_dtm, '\'');
        IF (v_dtm_column_name IS NOT NULL) THEN
          -- modifiers
          SET @v_tmp_from_str = CONCAT(v_src_table_alias, '.', v_dtm_column_name);
          SET @v_tmp_to_str   = CONCAT('tmp.', v_dtm_column_name);
          -- clause
          SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                                 ' ', REPLACE(v_dtm_cond_clause, @v_tmp_from_str, @v_tmp_to_str)
                                );
        END IF;
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
          COMMIT;
        END IF;
        --
        -- Drop FEDERATED PK-DTM Temporary Table
        --
        SET @sql_stmt = CONCAT('DROP TABLE IF EXISTS ', LINK_SCHEMA_NAME, '.', v_tmp_link_tbl_name);
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
        ELSE                
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF;
        --
        -- Create BLOCK PK IDs Table
        --
        SET v_tmp_block_pk_tbl_name = REPLACE(v_tmp_link_tbl_name, 'tmp_link_pk_ids', 'tmp_block_pk_ids');
        SET @sql_stmt = CONCAT('CREATE TABLE IF NOT EXISTS ', PROC_SCHEMA_NAME, '.', v_tmp_block_pk_tbl_name,
                               '(', @LF,
                               'pk_id  BIGINT NOT NULL,', @LF,
                               'PRIMARY KEY (pk_id)', @LF,
                               ')', @LF,
                               'ENGINE = InnoDB'
                              );
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF;
        --
        -- Get Number of Rows (PKs): @v_pk_num_rows
        --
        SET @v_pk_num_rows = 0;
        SET @sql_stmt = CONCAT('SELECT IFNULL(COUNT(pk_id), 0) INTO @v_pk_num_rows FROM ', PROC_SCHEMA_NAME, '.', v_tmp_pk_tbl_name);
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF;
        --
        -- Update initial_rows value for MASTER table during the Populate Staging Tables process
        --
        IF (v_control_type = STAGE_SCHEMA_TYPE) AND   -- AND  (v_src_table_type = MASTER_TABLE_TYPE) 
           (@v_pk_num_rows > 0) THEN
          --
          -- Recalculate and update proc_block_size
          --
          SELECT CASE WHEN @v_pk_num_rows > 1000000 THEN 1000000
                      WHEN @v_pk_num_rows > 100000  THEN 100000
                      WHEN @v_pk_num_rows > 10000   THEN 10000
                      ELSE 10000
                  END
            INTO v_proc_block_size;
          SET @sql_stmt = CONCAT('UPDATE ', PROC_SCHEMA_NAME, '.src_tables', @LF,
                                 '   SET initial_rows    = ', @v_pk_num_rows, ',', @LF,
                                 '       proc_block_size = ', v_proc_block_size, ',', @LF,
                                 '       modified_by     = ''', SUBSTRING_INDEX(USER(), "@", 1), ''',', @LF,
                                 '       modified_at     = ''', CURRENT_TIMESTAMP(), '''', @LF,
                                 ' WHERE host_alias      = ''', v_host_alias, '''', @LF,
                                 '   AND shard_number    = ''', v_shard_number, '''', @LF,
                                 '   AND src_schema_name = ''', v_src_schema_name, '''', @LF,
                                 '   AND src_table_name  = ''', v_src_table_name, ''''
                                );
          IF debug_mode_in THEN
            SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
            COMMIT;
          END IF;
        END IF;
        
        SET v_num_blocks = FLOOR(@v_pk_num_rows / v_proc_block_size) + 1;

        SET v_block_offset_num = 0;

        -- save AUTOCOMMIT mode
        SET @old_autocommit = (SELECT @@AUTOCOMMIT);
        SET @@AUTOCOMMIT = 0;

        -- ==============================
        -- For ALL Blocks
        -- ==============================
        -- Do we still have PK IDs for the current Object?
        WHILE (v_num_blocks > 0) DO

--          -- Order by PK in range of PKs
--          SET @sql_stmt = CONCAT(@sql_stmt, @LF, 
--                                 ' ORDER BY 1', @LF,
--                                 ' LIMIT ', v_block_offset_num, ', ', v_proc_block_size);

          --
          -- Start Block Transaction 
          --
          -- START TRANSACTION;  -- disable autocommit or SET autocommit = 0; ?
          --
          -- Truncate BLOCK PK IDs table
          --
          SET @sql_stmt = CONCAT('TRUNCATE TABLE ', PROC_SCHEMA_NAME, '.', v_tmp_block_pk_tbl_name);
          IF debug_mode_in THEN
            SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
          ELSE                
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
          END IF;
          --
          -- Insert Block (Offset) of MASTER Table's PK IDs from the PK TEMP (already filtered) table to the BLOCK TEMP table
          --
          SET @sql_stmt = CONCAT('INSERT INTO ', PROC_SCHEMA_NAME, '.', v_tmp_block_pk_tbl_name, ' (pk_id)', @LF,
                                 'SELECT pk_id', @LF,
                                 '  FROM ', PROC_SCHEMA_NAME, '.', v_tmp_pk_tbl_name, @LF,
                                 ' ORDER BY pk_id', @LF,
                                 ' LIMIT ', v_block_offset_num, ', ', v_proc_block_size);
          IF debug_mode_in THEN
            SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
            COMMIT;
          END IF;
          --
          -- Create Index On BLOCK TEMP table
          --
          SET @sql_stmt = CONCAT('CREATE INDEX ', v_tmp_block_pk_tbl_name , '$pk_id_idx ON ', PROC_SCHEMA_NAME, '.', v_tmp_block_pk_tbl_name, ' (pk_id)');
          IF debug_mode_in THEN
            SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
          END IF;
          -- ================================
          -- INSERT Block of data from LINK (federated) Table to DST (STAGE or DELTA) Table
          -- ================================
          SET @sql_stmt = CONCAT('INSERT INTO ', v_dst_schema_name, '.', v_src_table_name, @LF,
                                 '(', @LF,
                                 v_insert_columns, @LF,
                                 ') ', @LF,
                                 'SELECT ',
                                 v_select_columns, @LF,
                                 '  FROM ', LINK_SCHEMA_NAME, '.', v_host_alias, '_', v_shard_number, '_', v_src_schema_name, '_', v_src_table_name, ' ', v_src_table_alias);
          -- FORCE INDEX, if any
          IF (@v_pk_index_name IS NOT NULL) THEN
            SET @sql_stmt = CONCAT(@sql_stmt, @LF, 
                                 '  FORCE INDEX (', @v_pk_index_name, ')');
          END IF;
          
          SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                                 '  INNER JOIN ', PROC_SCHEMA_NAME, '.', v_tmp_block_pk_tbl_name, ' tmp', @LF,
                                 '    ON ', v_src_table_alias, '.', v_proc_pk_column_name, ' = tmp.pk_id');  -- block PK IDs filter
          --
          -- JOIN to shard_account_list table, if any
          --
          IF (v_sharding_column_name IS NOT NULL) THEN
            IF (v_host_alias = DB1_HOST_ALIAS) AND 
               (v_db1_shard_table_name IS NOT NULL) AND
               (v_db1_shards_per_host > 1) THEN
              SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                                     '  INNER JOIN ', LINK_SCHEMA_NAME, '.', v_host_alias, '_', v_shard_number, '_', v_db1_shard_schema_name, '_', v_db1_shard_table_name, ' ', v_db1_shard_table_alias, @LF, 
                                     '    ON ', v_src_table_alias, '.', v_sharding_column_name, ' = ', v_db1_shard_table_alias, '.', v_db1_shard_column_name
                                     );
            ELSEIF (v_host_alias = DB2_HOST_ALIAS) AND 
                   (v_db2_shard_table_name IS NOT NULL) AND
                   (v_db2_shards_per_host > 1) THEN
              SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                                     '  INNER JOIN ', LINK_SCHEMA_NAME, '.', v_host_alias, '_', v_shard_number, '_', v_db2_shard_schema_name, '_', v_db2_shard_table_name, ' ', v_db2_shard_table_alias, @LF, 
                                     '    ON ', v_src_table_alias, '.', v_sharding_column_name, ' = ', v_db2_shard_table_alias, '.', v_db2_shard_column_name
                                     );
            END IF;
          END IF;
          --  DTM Filter
          IF (v_dtm_column_name IS NOT NULL) THEN
            SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                                   '   ', v_dtm_cond_clause);
          END IF;
          -- 
          -- If DELTA: Update in case of duplicate key
          --
          IF (v_control_type = DELTA_SCHEMA_TYPE) THEN
            SET @sql_stmt = CONCAT(@sql_stmt, @LF,
              '  ON DUPLICATE KEY', @LF,
              '  UPDATE',
              REPLACE(v_dupl_update_columns, '  ', '         ')); 
           END IF;   
          -- Add ORDER BY clause
          IF (v_order_by_clause IS NOT NULL) THEN
            SET @sql_stmt = CONCAT(@sql_stmt, @LF,
              'ORDER BY ', v_order_by_clause);
          END IF;

          IF debug_mode_in THEN
            SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            -- Rows
            -- Attn! Debugger issue with ROW_COUNT() 
            -- SET @v_num_rows = (SELECT ROW_COUNT());
            SET v_proc_rows = v_proc_rows + ROW_COUNT();  -- for ON DUPLICATE KEY it will be 1 (New) or 2 (Update)
            DEALLOCATE PREPARE query;
            --
            -- Commit INSERT INTO STAGE or DELTA table 
            --
            COMMIT;
          END IF; 
          --
          -- Drop Index On BLOCK TEMP table
          --
          SET @sql_stmt = CONCAT('DROP INDEX ', v_tmp_block_pk_tbl_name , '$pk_id_idx ON ', PROC_SCHEMA_NAME, '.', v_tmp_block_pk_tbl_name);
          IF debug_mode_in THEN
            SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
          ELSE
            PREPARE query FROM @sql_stmt;
            EXECUTE query;
            DEALLOCATE PREPARE query;
          END IF;
          -- Next Block of IDs
          SET v_block_offset_num = v_block_offset_num + v_proc_block_size;
          -- Next Circle
          SET v_num_blocks = v_num_blocks - 1;

        END WHILE; -- proc_blocks
        -- ==============================

        -- restore AUTOCOMMIT mode
        SET @@AUTOCOMMIT = @old_autocommit;

        --
        -- Drop Local Temporary Tables
        --
        SET @sql_stmt = CONCAT('DROP TABLE IF EXISTS ', PROC_SCHEMA_NAME, '.', v_tmp_pk_tbl_name);
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
        ELSE                
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF;
        -- tmp_block_pk table
        SET @sql_stmt = CONCAT('DROP TABLE IF EXISTS ', PROC_SCHEMA_NAME, '.', v_tmp_block_pk_tbl_name);
        IF debug_mode_in THEN
          SELECT CONCAT(CAST(@sql_stmt AS CHAR), ";", @LF) AS debug_sql;
        ELSE                
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
        END IF;

      ELSE   

        -- proc_block_size = 0  (NO BLOCKS OF PKs DURING MIGRATION) 
        -- proc_block_size = -1 (NO BLOCKS OF PKs DURING MIGRATION) AND (TRUNCATE STAGE table before INSERT FROM DELTA)
        START TRANSACTION;
        -- ================================
        -- INSERT data from LINK (federated) Table(s) to DST (STAGE or DELTA) Table
        -- ================================
        SET @sql_stmt = CONCAT('INSERT INTO ', v_dst_schema_name, '.', v_src_table_name, @LF, 
                               '(', @LF,
                               v_insert_columns, @LF,
                               ') ', @LF,
                               'SELECT ',
                               v_select_columns, @LF,
                               '  FROM ', LINK_SCHEMA_NAME, '.', v_host_alias, '_', v_shard_number, '_', v_src_schema_name, '_', v_src_table_name, ' ', v_src_table_alias);
        --
        -- Add JOIN to shard_acount_list table, if any
        --
        IF (v_sharding_column_name IS NOT NULL) THEN
          IF (v_host_alias = DB1_HOST_ALIAS) AND 
             (v_db1_shard_table_name IS NOT NULL) AND
             (v_db1_shards_per_host > 1) THEN
            SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                                   '  INNER JOIN ', LINK_SCHEMA_NAME, '.', v_host_alias, '_', v_shard_number, '_', v_db1_shard_schema_name, '_', v_db1_shard_table_name, ' ', v_db1_shard_table_alias, @LF, 
                                   '    ON ', v_src_table_alias, '.', v_sharding_column_name, ' = ', v_db1_shard_table_alias, '.', v_db1_shard_column_name
                                   );
          ELSEIF (v_host_alias = DB2_HOST_ALIAS) AND 
                 (v_db2_shard_table_name IS NOT NULL)  AND
                 (v_db2_shards_per_host > 1) THEN
            SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                                   '  INNER JOIN ', LINK_SCHEMA_NAME, '.', v_host_alias, '_', v_shard_number, '_', v_db2_shard_schema_name, '_', v_db2_shard_table_name, ' ', v_db2_shard_table_alias, @LF, 
                                   '    ON ', v_src_table_alias, '.', v_sharding_column_name, ' = ', v_db2_shard_table_alias, '.', v_db2_shard_column_name
                                   );
          END IF;                         
        END IF;
        -- DTM filter
        IF (v_dtm_column_name IS NOT NULL) THEN
          -- if modified_dtm field is in the table - add v_dtm_cond_clause
          SET @sql_stmt = CONCAT(@sql_stmt, @LF,
                                 '   ', v_dtm_cond_clause);
        END IF;  
        -- 
        -- If DELTA: Update in case of duplicate key
        --
        IF (v_control_type = DELTA_SCHEMA_TYPE) THEN
          SET @sql_stmt = CONCAT(@sql_stmt, @LF,
            '  ON DUPLICATE KEY', @LF,
            '  UPDATE',
            REPLACE(v_dupl_update_columns, '  ', '         ')); 
         END IF;   
        -- ORDER BY clause
        IF (v_order_by_clause IS NOT NULL) THEN
          SET @sql_stmt = CONCAT(@sql_stmt, @LF,
            'ORDER BY ', v_order_by_clause);
        END IF;
        IF debug_mode_in THEN
          SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          -- Rows
          -- Attn! Debugger issue with ROW_COUNT() 
          -- SET @v_num_rows = (SELECT ROW_COUNT());
          SET v_proc_rows = v_proc_rows + ROW_COUNT();  -- for 'ON DUPLICATE KEY' it will be 1 (New) or 2 (Update)
          DEALLOCATE PREPARE query;
          --
          -- Commit INSERT INTO STAGE or DELTA table 
          --
          COMMIT;
        END IF; 

      END IF;  -- IF-ELSE (v_proc_block_size > 0)
      --
      -- Enable KEYs on DST (STAGE or DELTA) table
      --
      SET @sql_stmt = CONCAT('ALTER TABLE ', v_dst_schema_name, '.', v_src_table_name, ' ENABLE KEYS');
      IF debug_mode_in THEN
        SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF; 

      -- Process end time
      SET v_download_timing_end = CURRENT_TIMESTAMP();
      -- Duration
      SET v_proc_duration = TIMESTAMPDIFF (SECOND, v_download_timing_start, v_download_timing_end);

      -- Save proc_rows, proc_duration values for STAGE and DELTA tables
      -- and download_status = 1
      IF debug_mode_in THEN
        SET @sql_stmt = CONCAT(@LF,
         'UPDATE elt.control_downloads', @LF,
         '   SET proc_rows       = ', v_proc_rows, ',', @LF,           -- rows
         '       proc_duration   = ', v_proc_duration, ',', @LF,       -- duration in sec
         '       download_status = 1,', @LF,
         '       modified_by     = ''', SUBSTRING_INDEX(USER(), "@", 1), ''',', @LF,
         '       modified_at     = ''', CURRENT_TIMESTAMP(), '''', @LF,
         ' WHERE control_download_id = ', v_control_download_id);
         SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
      ELSE
        UPDATE elt.control_downloads
          SET proc_rows       = v_proc_rows,                  -- rows
              proc_duration   = v_proc_duration,              -- duration
              download_status = 1,                            -- downloaded
              modified_by     = SUBSTRING_INDEX(USER(), "@", 1),
              modified_at     = CURRENT_TIMESTAMP()
        WHERE control_download_id = v_control_download_id;  -- PK
        COMMIT;
      END IF;
      -- Save append_status = 1 for STAGE tables
      IF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
        IF debug_mode_in THEN
          SET @sql_stmt = CONCAT(@LF,
           'UPDATE elt.control_downloads', @LF,
           '   SET append_status   = 1,', @LF,
           '       modified_by     = ''', SUBSTRING_INDEX(USER(), "@", 1), ''',', @LF,
           '       modified_at     = ''', CURRENT_TIMESTAMP(), '''', @LF,
           ' WHERE control_download_id = ', v_control_download_id);
           SELECT CONCAT(CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
        ELSE
          UPDATE elt.control_downloads
            SET append_status   = 1,                            -- appended
                modified_by     = SUBSTRING_INDEX(USER(), "@", 1),
                modified_at     = CURRENT_TIMESTAMP()
          WHERE control_download_id = v_control_download_id;  -- PK
          COMMIT;
        END IF;
      END IF;  
      -- Drop LINK table
      SET @sql_stmt = CONCAT('DROP TABLE IF EXISTS ', 
                             LINK_SCHEMA_NAME, '.', v_host_alias, '_', v_shard_number, '_', v_src_schema_name, '_', v_src_table_name
                            );
      IF debug_mode_in THEN
        SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF; 
      -- FLUSH TABLES;
      SET error_code_out = 0;
    END LOOP;  -- main_proc_tables
    -- ================================
    CLOSE main_proc_tables_cur;
    -- recover MySQL Logs 
    -- SET @@GLOBAL.GENERAL_LOG    = @old_general_log;
    -- SET @@GLOBAL.SLOW_QUERY_LOG = @old_slow_query_log;
    -- Final Commit
    -- COMMIT;
  END;  -- exec:    
  -- SET FOREIGN_KEY_CHECKS = @old_foreign_key_checks;
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END$$

DELIMITER ;

SELECT '====> Procedure ''load_elt_data'' has been created' AS "Info:" FROM dual;
