/*
  Version:
    2011.11.12.01
  Script:
    05_create_proc_create_elt_schema.sql
  Description:
    CREATE SCHEMA IF NOT EXISTS <schema_name>
    LINK:   CREATE FEDERATED TABLEs                 - from elt.src_tables
    STAGE/DELTA: CREATE TABLEs                      - from elt.src_tables
                 COLUMNs, type, nullable, default   - from source tables (information_schema of the remote DBs)
                 INDEXes                            - from source tables (information_schema of the remote DBs)
             
  Input:
    * schema_type   - Schema Type. 
                      Values: 
                        * LINK  - Link (for Dyn Created Federated Tables)
                        * DELTA - Static Tables
                        * STAGE - Static Tables
    * debug_mode    - Debug Mode.
                      Values:
                        * TRUE  (1) - show SQL statements
                        * FALSE (0) - execute SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\05_create_proc_create_elt_schema.sql
  Usage:
    CALL elt.create_elt_schema (@err, 'LINK',  FALSE);   -- db_link  (shard tables)
    CALL elt.create_elt_schema (@err, 'STAGE', TRUE);    -- db_stage (data tables)
    CALL elt.create_elt_schema (@err, 'DELTA', TRUE);    -- db_delta (data tables) 
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.create_elt_schema
$$

CREATE PROCEDURE elt.create_elt_schema
(
  OUT error_code_out  INTEGER,
   IN schema_type_in  VARCHAR(16),      -- [LINK|STAGE|DELTA]
   IN debug_mode_in   BOOLEAN
)
BEGIN

  DECLARE DB1_HOST_ALIAS         VARCHAR(16) DEFAULT 'db1';
  DECLARE DB2_HOST_ALIAS         VARCHAR(16) DEFAULT 'db2';

  DECLARE LINK_SCHEMA_TYPE       VARCHAR(16)  DEFAULT 'LINK';          -- link schema type
  DECLARE STAGE_SCHEMA_TYPE      VARCHAR(16)  DEFAULT 'STAGE';         -- stage schema type
  DECLARE DELTA_SCHEMA_TYPE      VARCHAR(16)  DEFAULT 'DELTA';         -- delta schema type

  DECLARE PROC_SCHEMA_NAME       VARCHAR(64) DEFAULT 'elt';           -- control
  DECLARE LINK_SCHEMA_NAME       VARCHAR(64) DEFAULT 'db_link';     -- link
  DECLARE STAGE_SCHEMA_NAME      VARCHAR(64) DEFAULT 'db_stage';    -- stage
  DECLARE DELTA_SCHEMA_NAME      VARCHAR(64) DEFAULT 'db_delta';    -- delta

  DECLARE v_schema_type          VARCHAR(16) DEFAULT schema_type_in;

  DECLARE v_shard_number         VARCHAR(2);    -- [01|02|...]
  DECLARE v_src_schema_name      VARCHAR(64);   -- SRC Schema name
  DECLARE v_src_table_name       VARCHAR(64);   -- SRC Table Name 
  
  DECLARE v_shard_schema_name    VARCHAR(64);   -- Shard Schema name
  DECLARE v_shard_table_name     VARCHAR(64);   -- Shard Table Name 
  
  DECLARE v_src_conn_str         VARCHAR(255);
  DECLARE v_host_alias           CHAR(16) DEFAULT 'db1';    -- loop for db1 and db2 host aliases

  DECLARE done                   BOOLEAN DEFAULT FALSE;
 
  --
  -- Shards, Schemas, and Tables
  --
  DECLARE src_tables_cur CURSOR
  FOR
    SELECT st.shard_number,                                          -- [01|02|...]
           st.src_schema_name,
           st.src_table_name
      FROM elt.src_tables              st 
        INNER JOIN elt.shard_profiles  spf
          ON st.shard_profile_id = spf.shard_profile_id
            AND spf.status = 1               -- active host profile
     WHERE spf.host_alias = v_host_alias     -- [db1|db2]
       AND st.src_table_load_status  = 1     -- active SRC tables
       AND st.src_table_valid_status = 1     -- valid SRC tables
       AND st.src_table_name <> IFNULL(spf.shard_table_name, '');

  --
  -- Sharding Tables
  --
  DECLARE shard_tables_cur CURSOR
  FOR
    SELECT shard_number,                                          -- [01|02|...]
           shard_schema_name,
           shard_table_name
      FROM elt.shard_profiles
     WHERE host_alias = v_host_alias     -- [db1|db2]
       AND status     = 1;               -- active host profile

  -- 'NOT FOUND' Handler
  DECLARE CONTINUE HANDLER 
  FOR NOT FOUND 
  SET done = TRUE;
  
  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF       = CHAR(10); 
  SET @sql_stmt = '';

  SET error_code_out = -2;

  SET v_schema_type = UPPER(v_schema_type);
  
  -- ==================================
  -- DROP SCHEMA
  -- ==================================
  IF (v_schema_type = LINK_SCHEMA_TYPE) THEN
    SET @sql_stmt = CONCAT('DROP SCHEMA IF EXISTS ', LINK_SCHEMA_NAME);
  ELSEIF (v_schema_type = DELTA_SCHEMA_TYPE) THEN
    SET @sql_stmt = CONCAT('DROP SCHEMA IF EXISTS ', DELTA_SCHEMA_NAME);
  ELSEIF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
    SET @sql_stmt = CONCAT('DROP SCHEMA IF EXISTS ', STAGE_SCHEMA_NAME);
  END IF;  
  
  IF LENGTH(@sql_stmt) > 1 THEN
    IF debug_mode_in THEN
      SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
    ELSE
      PREPARE query FROM @sql_stmt;
      EXECUTE query;
      DEALLOCATE PREPARE query;
      COMMIT;
    END IF; 
  END IF;  
  
  -- ==================================
  -- CREATE SCHEMA
  -- ==================================
  -- The db_link schema is recreated here as it is a virtual schema for views 
  -- and will be dropped at the end of delta processing
  IF (v_schema_type = LINK_SCHEMA_TYPE) THEN
    SET @sql_stmt = CONCAT('CREATE SCHEMA ', LINK_SCHEMA_NAME,  ' DEFAULT CHARACTER SET utf8 COLLATE utf8_bin');
  ELSEIF (v_schema_type = DELTA_SCHEMA_TYPE) THEN
    SET @sql_stmt = CONCAT('CREATE SCHEMA ', DELTA_SCHEMA_NAME, ' DEFAULT CHARACTER SET utf8 COLLATE utf8_bin');
  ELSEIF (v_schema_type = STAGE_SCHEMA_TYPE) THEN
    SET @sql_stmt = CONCAT('CREATE SCHEMA ', STAGE_SCHEMA_NAME, ' DEFAULT CHARACTER SET utf8 COLLATE utf8_bin');
  END IF;  
  IF debug_mode_in THEN
    SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
  ELSE
    PREPARE query FROM @sql_stmt;
    EXECUTE query;
    DEALLOCATE PREPARE query;
    COMMIT;
  END IF; 

  -- ==================================
  -- Create tables in STAGE or DELTA schemas
  -- ==================================
  IF (v_schema_type = STAGE_SCHEMA_TYPE) OR 
     (v_schema_type = DELTA_SCHEMA_TYPE) THEN
  
    SET v_host_alias = DB1_HOST_ALIAS;  -- start from DB1
    -- ==================================
    -- Loop for all DB Host Aliases
    -- ==================================
    src_host_aliases:
    LOOP

      OPEN src_tables_cur;     -- F(v_host_alias)
      -- ==================================
      -- Loop for all elt.src_tables having status = 1
      -- ==================================
      src_tables:
      LOOP
        SET done = FALSE;
        FETCH src_tables_cur
        INTO v_shard_number,         -- [01|02|...] 
             v_src_schema_name,      -- SRC Schema Name
             v_src_table_name;       -- SRC Table Name
        IF done THEN
          LEAVE src_tables;
        END IF;
        IF (v_src_schema_name IS NULL) THEN
          SELECT "Couldn't get information about SRC tables. Check if SRC tables have been validated." AS "ERROR" FROM dual;
          SET error_code_out = -3;
          LEAVE src_tables;
        END IF;
        -- ==============================
        -- DROP TABLE
        -- ==============================
        CALL elt.drop_elt_table (@err_num, v_schema_type, v_host_alias, v_shard_number, v_src_schema_name, v_src_table_name, debug_mode_in);
        IF @err_num <> 0 THEN
          SELECT CONCAT("Could not drop \'", v_src_table_name, "\' table in ", v_schema_type, " schema") AS "ERROR" FROM dual;
          SET error_code_out = -4;
          LEAVE src_tables;
        END IF;
        -- ==============================
        -- CREATE TABLE
        -- ==============================
        CALL elt.create_elt_table (@err_num, v_schema_type, v_host_alias, v_shard_number, v_src_schema_name, v_src_table_name, debug_mode_in);
        IF @err_num <> 0 THEN
          SELECT CONCAT("Could not create \'", v_src_table_name, "\' table in ", v_schema_type, " schema") AS "ERROR" FROM dual;
          SET error_code_out = -5;
          LEAVE src_tables;
        END IF;
      END LOOP;  -- for all TABLEs (src_tables)
      -- ================================
      CLOSE src_tables_cur;
    
      -- end of loop?
      IF (error_code_out < -2) THEN
        LEAVE src_host_aliases;
      ELSEIF (v_host_alias = DB2_HOST_ALIAS) THEN
        SET error_code_out = 0;
        LEAVE src_host_aliases;
      END IF;
      -- go to the DB2 tables
      IF (v_host_alias = DB1_HOST_ALIAS) THEN
        SET v_host_alias = DB2_HOST_ALIAS;
      END IF;  
      SET error_code_out = 0;
    END LOOP;  -- for all DBn (src_host_aliases)
    -- ==================================

  ELSEIF (v_schema_type = LINK_SCHEMA_TYPE) THEN
  
    SET v_host_alias = DB1_HOST_ALIAS;  -- start from DB1

    -- ==================================
    -- Loop for all DB Host Aliases
    -- ==================================
    shard_host_aliases:
    LOOP

      OPEN shard_tables_cur;     -- F(v_host_alias, load_status=1, valid_status=1)
      -- ==================================
      -- Loop for all elt.src_tables having status = 1
      -- ==================================
      shard_tables:
      LOOP
        SET done = FALSE;
        FETCH shard_tables_cur 
        INTO v_shard_number,         -- [01|02|...] 
             v_shard_schema_name,    -- Shard Schema Name
             v_shard_table_name;     -- Shard Table Name
        IF done THEN
          LEAVE shard_tables;
        END IF;
        IF (v_shard_number IS NULL) THEN
          SELECT "Couldn't get information about SHARDING tables. Check if SRC tables have been validated." AS "ERROR" FROM dual;
          SET error_code_out = -6;
          LEAVE shard_tables;
        END IF;
        --
        -- Create Shard FEDERATED table
        --
        IF (v_shard_schema_name IS NOT NULL) AND (v_shard_table_name IS NOT NULL)  THEN
          -- ==============================
          -- DROP TABLE
          -- ==============================
          CALL elt.drop_elt_table (@err_num, v_schema_type, v_host_alias, v_shard_number, v_shard_schema_name, v_shard_table_name, debug_mode_in);
          IF @err_num <> 0 THEN
            SELECT CONCAT("Could not drop \'", v_src_table_name, "\' table in ", v_schema_type, " schema") AS "ERROR" FROM dual;
            SET error_code_out = -4;
            LEAVE shard_tables;
          END IF;
          -- ==============================
          -- CREATE TABLE
          -- ==============================
          CALL elt.create_elt_table (@err_num, v_schema_type, v_host_alias, v_shard_number, v_shard_schema_name, v_shard_table_name, debug_mode_in);
          IF @err_num <> 0 THEN
            SELECT CONCAT("Could not create \'", v_src_table_name, "\' table in ", v_schema_type, " schema") AS "ERROR" FROM dual;
            SET error_code_out = -5;
            LEAVE shard_tables;
          END IF;
        END IF;  
      END LOOP;  -- for all SHARDING TABLE (shard_tables)
      -- ================================
      CLOSE shard_tables_cur;
      -- end of loop?
      IF (v_host_alias = DB2_HOST_ALIAS) OR (error_code_out < -2) THEN
        LEAVE shard_host_aliases;
      END IF;
      -- go to the DB2 tables
      IF (v_host_alias = DB1_HOST_ALIAS) THEN
        SET v_host_alias = DB2_HOST_ALIAS;
      END IF;  
      SET error_code_out = 0;
    END LOOP;  -- for all DBn (shard_host_aliases)
    -- ==================================
  END IF; -- IF (v_schema_type = STAGE_SCHEMA_TYPE) OR  (v_schema_type = DELTA_SCHEMA_TYPE)

  IF (error_code_out = -2) THEN
    SET error_code_out = 0;
  END IF;  
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END
$$

DELIMITER ;

SELECT '====> Procedure ''create_elt_schema'' has been created' AS "Info:" FROM dual;
