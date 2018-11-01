/*
  Version:
    2011.12.11.01
  Script:
    02_create_proc_populate_src_tables.sql
  Description:
    Fill src_tables table.
  Input:
    * host_alias             - Host Alias   [db1|db2]
    * db_engine_type_in      - DB Engine    [InnoDB|TokuDB]
    * src_schema_name_in     - Schema Name.
    * in_table_list_in       - List of tables for IN clause 
    * not_in_table_list_in   - List of tables for NOT IN clause 
    * like_table_list_in     - List of tables for LIKE clause 
    * not_like_table_list_in - List of tables for NOT LIKE clause 
    * list_delimiter_in      - Separator for lists above - any value, for instance [',' | ';' | ... ]
    * debug_mode_in          - Debug Mode. Values:
                               * FALSE (0) - execute SQL statements
                               * TRUE  (1) - show SQL statements
  Output:
    error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\02_create_proc_populate_src_tables.sql
  Usage:
    CALL elt.populate_src_tables (@err, 'db1', 'TokuDB', 'account', 'account; account_log', NULL, NULL, NULL, ';', TRUE);
    CALL elt.populate_src_tables (@err, 'db2', 'TokuDB', 'catalog', 'content_item; content_item_log', NULL, NULL, NULL, ';', TRUE);
    CALL elt.populate_src_tables (@err, 'db2', 'TokuDB', 'catalog', 'item; item_log', NULL, NULL, NULL, ';', TRUE);
  Result:
*/
DELIMITER $$ 

DROP PROCEDURE IF EXISTS elt.populate_src_tables$$ 

CREATE PROCEDURE elt.populate_src_tables
(
 OUT error_code_out         INTEGER,
  IN host_alias_in          VARCHAR(16),   -- Host Alias   [db1|db2]
  IN db_engine_type_in      VARCHAR(64),   -- DB Engine    [InnoDB|TokuDB]
  IN src_schema_name_in     VARCHAR(64),   -- SRC Schema Name
  IN in_table_list_in       TEXT,          -- IN       table list
  IN not_in_table_list_in   TEXT,          -- NOT IN   table list
  IN like_table_list_in     TEXT,          -- LIKE     table list 
  IN not_like_table_list_in TEXT,          -- NOT LIKE table list
  IN list_delimiter_in      VARCHAR(10),   -- list separator
  IN debug_mode_in          BOOLEAN
) 
BEGIN

  DECLARE PROJECT_NAME               VARCHAR(16) DEFAULT 'db';
  
  DECLARE DB1_HOST_ALIAS             VARCHAR(16) DEFAULT 'db1';
  DECLARE DB2_HOST_ALIAS             VARCHAR(16) DEFAULT 'db2';
  
  DECLARE STAGE_SCHEMA_TYPE          VARCHAR(64) DEFAULT 'STAGE';
  DECLARE DELTA_SCHEMA_TYPE          VARCHAR(64) DEFAULT 'DELTA';

  DECLARE LINK_TMP_SCHEMA_NAME       VARCHAR(64) DEFAULT 'db_link_tmp';     -- for temporary FED tables

  DECLARE MDF_DTM_COL_NAME           VARCHAR(64) DEFAULT "modified_dtm";      -- catalog
  DECLARE LAST_MOD_TIME_COL_NAME     VARCHAR(64) DEFAULT "last_mod_time";     -- loag_catalog
  DECLARE LOG_CRT_DTM_COL_NAME       VARCHAR(64) DEFAULT "log_created_dtm";   -- catalog
  DECLARE LOG_MDF_DTM_COL_NAME       VARCHAR(64) DEFAULT "log_modified_dtm";  -- account   

  DECLARE ACCT_COL_NAME              VARCHAR(64) DEFAULT "account_id";
  DECLARE OWNER_ACCT_COL_NAME        VARCHAR(64) DEFAULT "owner_account_id";
  DECLARE DUMMY_ACCT_COL_NAME        VARCHAR(64) DEFAULT "dummy_account_id";

  DECLARE v_host_alias               VARCHAR(16); 
  DECLARE v_shard_num                TINYINT     DEFAULT 1;

  DECLARE v_shard_profile_id         INTEGER;       -- shard info
  DECLARE v_shard_number             CHAR(2);       -- char  
  DECLARE v_shard_schema_name        VARCHAR(64);
  DECLARE v_shard_table_name         VARCHAR(64);
  DECLARE v_db_user_name             VARCHAR(64);   -- connection
  DECLARE v_db_user_pwd              VARCHAR(64);
  DECLARE v_host_ip_address          VARCHAR(128);
  DECLARE v_host_port_num            VARCHAR(6);

  DECLARE v_table_clause             TEXT(10000);
  DECLARE v_entry_name               VARCHAR(128);

  -- Handler
  DECLARE EXIT HANDLER
  FOR SQLSTATE VALUE '23000'
    SELECT CONCAT('ERROR in Procedure: fill_src_tables [Host: ', v_host_alias, 
                  '; Schema: ', src_schema_name_in, ']', @LF, @ERROR) AS err_cond FROM dual;

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF = CHAR(10);

  exec:
  BEGIN

    SET v_host_alias = LOWER(host_alias_in);
    --
    -- Get Number of active Shards for a given Host
    --
    SET @src_shard_nums = 0;
    
    SELECT COUNT(*)
      INTO @src_shard_nums
      FROM elt.shard_profiles
     WHERE host_alias = v_host_alias    -- [db1|db2]
       AND status     = 1;              -- active shard

    IF @src_shard_nums = 0 THEN
      SET error_code_out = -3;
      LEAVE exec;
    END IF;
    
    SET error_code_out = -2; 

    -- ================================
    -- Create temporary FED tables to remote IS
    -- ================================
    CALL elt.create_info_link_fed_tables (@err_num, LINK_TMP_SCHEMA_NAME, v_host_alias, debug_mode_in);
    IF (@err_num <> 0) THEN
      SELECT CONCAT('Procedure \'create_info_link_tables\', schema ''', LINK_TMP_SCHEMA_NAME, ''', ERROR: ', @err_num);
      LEAVE exec;
    END IF;

    -- ================================
    WHILE v_shard_num <= @src_shard_nums DO
      --
      -- Get shard_profile_id
      --
      SELECT spf.shard_profile_id,
             spf.shard_number,
             spf.shard_schema_name,
             spf.shard_table_name,
             spf.db_user_name,
             spf.db_user_pwd,
             spf.host_ip_address,
             spf.host_port_num
        INTO v_shard_profile_id,
             v_shard_number,
             v_shard_schema_name,
             v_shard_table_name,
             v_db_user_name,
             v_db_user_pwd,
             v_host_ip_address,
             v_host_port_num
        FROM elt.shard_profiles  spf
       WHERE spf.host_alias   = v_host_alias                              -- [db1|db2]
         AND spf.shard_number = LPAD(CAST(v_shard_num AS CHAR), 2, '0')   -- [01|02|...]
         AND spf.status       = 1;                                        -- active shard

      --
      -- Check record in src_tables 
      -- Note: UNIQUE KEY src_tables$shard_conn_schema_table_uidx (shard_profile_id, src_schema_name, src_table_name)
      --
      -- Get Where clause as: "AND table_name NOT LIKE '%account' AND table_name NOT LIKE '%account_log'"
      SET v_entry_name = 'st.src_table_name';
      SET v_table_clause = (SELECT elt.split_condition_string (v_entry_name, 
                                                               in_table_list_in, 
                                                               not_in_table_list_in, 
                                                               like_table_list_in, 
                                                               not_like_table_list_in, 
                                                               list_delimiter_in
                                                              )
                           );

      SET @is_table_defined = 0;

      SET @sql_stmt = CONCAT('
      SELECT COUNT(*)
        INTO @is_table_defined
        FROM elt.src_tables  st
       WHERE st.shard_profile_id = ', v_shard_profile_id, '         -- host:port
         AND st.src_schema_name  = ''', src_schema_name_in, '''',   -- schema name
         @LF, 
         v_table_clause);                                           -- table name filter
      IF debug_mode_in THEN
        SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
      END IF; 
      
      -- ==============================
      IF @is_table_defined = 0 THEN

        SET @sql_stmt = CONCAT('
          INSERT INTO elt.src_tables 
          (
            shard_profile_id,
            host_alias,                 -- host alias from shard_profiles
            shard_number,               -- shard number from shard_profiles 
            src_schema_name,  
            src_table_name,
            src_table_alias, 
            src_table_type, 
            src_table_load_status,
            src_table_valid_status,
            override_dtm,
            dtm_column_name,            -- dtm
            sharding_column_name,
            proc_pk_column_name,        -- PK
            proc_block_size,            -- block size
            delta_schema_name,
            dst_schema_name,
            dst_table_name,
            db_engine_type,
            created_by, 
            created_at
          )
          SELECT DISTINCT ', v_shard_profile_id, '        AS shard_profile_id,
                 ''', v_host_alias, '''                   AS host_alias,
                 ''', v_shard_number, '''                 AS shard_number,
                 isc.table_schema                         AS src_schema_name,
                 isc.table_name                           AS src_table_name,
                 LOWER(elt.translate(elt.initcap(REPLACE(isc.table_name, "_", " ")), 
                                     "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz", 
                                     "ABCDEFGHIJKLMNOPQRSTUVWXYZ")
                      )                                   AS src_table_alias,
                 CASE WHEN POSITION("_log" IN isc.table_name) > 0 THEN "LOG"
                                                                  ELSE "MASTER"
                 END                                      AS src_table_type,
                 1                                        AS src_table_load_status,      -- 1 if SRC table satisfy the filters
                 0                                        AS src_table_valid_status,     -- default value, should be changed by validator
                 CAST("2000-01-01 00:00:00" AS DATETIME)  AS override_dtm, 
                 q4.dtm_column_name                       AS dtm_column_name,
                 q3.column_name                           AS sharding_column_name,
                 IFNULL(q1.pk_column_name, 
                        q2.first_column_name)             AS proc_pk_column_name, 
                 IF (q4.dtm_column_name IS NULL,
                     -1,                                                                  -- NO DTM - entire table (STAGE or DELTA)  
                     IF(q1.pk_column_name IS NULL,
                        0,                                                                -- NO PK - no blocks (STAGE)
                        IF ((''', v_host_alias, ''' = ''', DB1_HOST_ALIAS, ''') AND (isc.table_name NOT LIKE "%_log"), 
                            0,
                            IF (
                                (''', v_host_alias, ''' = ''', DB2_HOST_ALIAS, ''') AND (isc.table_name NOT LIKE "%_log"), 
                                100000,
                                IF ((isc.table_name LIKE "%_log"),
                                    1000000, 
                                    0
                                   )
                               )
                           )
                       )  
                   )                                      AS proc_block_size,
                 LOWER(CONCAT(''', PROJECT_NAME, ''', "_", ''', DELTA_SCHEMA_TYPE, '''))  AS delta_schema_name,  
                 LOWER(CONCAT(''', PROJECT_NAME, ''', "_", ''', STAGE_SCHEMA_TYPE, '''))  AS dst_schema_name,
                 isc.table_name                           AS dst_table_name,
                 ''', db_engine_type_in, '''              AS db_engine_type, 
                 SUBSTRING_INDEX(CURRENT_USER, "@", 1)    AS created_by,
                 CURRENT_TIMESTAMP()                      AS created_at');

        -- PK column
        IF (v_host_alias = DB1_HOST_ALIAS) THEN
          SET @sql_stmt = CONCAT(@sql_stmt, '
            FROM ', LINK_TMP_SCHEMA_NAME, '.db1_information_schema_columns  isc
              LEFT OUTER JOIN
                (SELECT isc1.table_schema,
                        isc1.table_name,
                        IF((isc1.table_name LIKE "%_log"),
                           REPLACE(isc1.column_name, "_log", ""),
                           isc1.column_name
                          )  AS pk_column_name
                   FROM ', LINK_TMP_SCHEMA_NAME, '.db1_information_schema_columns  isc1
                  WHERE isc1.column_key = "PRI"
                ) q1
                ON isc.table_schema  = q1.table_schema
                  AND isc.table_name = q1.table_name');
        ELSE
          SET @sql_stmt = CONCAT(@sql_stmt, '
            FROM ', LINK_TMP_SCHEMA_NAME, '.db2_information_schema_columns  isc
              LEFT OUTER JOIN
                (SELECT isc1.table_schema,
                        isc1.table_name,
                        IF((isc1.table_name LIKE "%_log"),
                           REPLACE(isc1.column_name, "_log", ""),
                           isc1.column_name
                          )  AS pk_column_name
                   FROM ', LINK_TMP_SCHEMA_NAME, '.db2_information_schema_columns  isc1
                  WHERE isc1.column_key = "PRI"
                ) q1
                ON isc.table_schema  = q1.table_schema
                  AND isc.table_name = q1.table_name');
        END IF;

        -- Get First column name if no PK on table
        IF (v_host_alias = DB1_HOST_ALIAS) THEN
          SET @sql_stmt = CONCAT(@sql_stmt, '
            LEFT OUTER JOIN
              (SELECT isc2.table_schema,
                      isc2.table_name,
                      isc2.column_name  AS first_column_name
                 FROM ', LINK_TMP_SCHEMA_NAME, '.db1_information_schema_columns  isc2
                WHERE isc2.ordinal_position = 1
              ) q2
              ON isc.table_schema  = q2.table_schema
                AND isc.table_name = q2.table_name');
        ELSE
          SET @sql_stmt = CONCAT(@sql_stmt, '
            LEFT OUTER JOIN
              (SELECT isc2.table_schema,
                      isc2.table_name,
                      isc2.column_name  AS first_column_name
                 FROM ', LINK_TMP_SCHEMA_NAME, '.db2_information_schema_columns  isc2
                WHERE isc2.ordinal_position = 1
              ) q2
              ON isc.table_schema  = q2.table_schema
                AND isc.table_name = q2.table_name');
        END IF;

        -- Sharding (DB2 only?)
        IF (v_host_alias = DB1_HOST_ALIAS) THEN
          SET @sql_stmt = CONCAT(@sql_stmt, '
            LEFT OUTER JOIN
             (SELECT isc3.table_schema,
                     isc3.table_name,
                     isc3.column_name 
                FROM ', LINK_TMP_SCHEMA_NAME, '.db1_information_schema_columns  isc3
               WHERE isc3.column_name IN (''', DUMMY_ACCT_COL_NAME, ''')               -- should not be in DB1
             )  q3
              ON isc.table_schema  = q3.table_schema
                AND isc.table_name = q3.table_name');
        ELSE
          SET @sql_stmt = CONCAT(@sql_stmt, '
            LEFT OUTER JOIN
             (SELECT isc3.table_schema,
                     isc3.table_name,
                     isc3.column_name 
                FROM ', LINK_TMP_SCHEMA_NAME, '.db2_information_schema_columns  isc3
               WHERE isc3.column_name IN (''', ACCT_COL_NAME, ''',
                                          ''', OWNER_ACCT_COL_NAME, '''
                                         )
                 AND isc3.column_key <> "PRI"
               ORDER BY isc3.table_schema, isc3.table_name, isc3.column_name DESC      -- owner_account_id at the first place
             )  q3
              ON isc.table_schema  = q3.table_schema
                AND isc.table_name = q3.table_name');
        END IF;
        
        -- Delta Process
        IF (v_host_alias = DB1_HOST_ALIAS) THEN
          SET @sql_stmt = CONCAT(@sql_stmt, '
            LEFT OUTER JOIN
             (SELECT isc4.table_schema,
                     isc4.table_name,
                     IF(((isc4.table_name LIKE "%_log") 
                          AND (isc4.column_name LIKE "log_%")) 
                         OR (isc4.table_name NOT LIKE "%_log"), 
                         isc4.column_name, 
                         NULL
                       )  AS dtm_column_name
                FROM ', LINK_TMP_SCHEMA_NAME, '.db1_information_schema_columns  isc4
               WHERE isc4.column_name IN (''', MDF_DTM_COL_NAME, ''',
                                          ''', LAST_MOD_TIME_COL_NAME, ''',
                                          ''', LOG_CRT_DTM_COL_NAME, ''',
                                          ''', LOG_MDF_DTM_COL_NAME, '''
                                         )
                 AND IF(((isc4.table_name LIKE "%_log") 
                          AND (isc4.column_name LIKE "log_%")) 
                         OR (isc4.table_name NOT LIKE "%_log"), 
                         1, 
                         NULL
                       )  IS NOT NULL
             )  q4
              ON isc.table_schema  = q4.table_schema
                AND isc.table_name = q4.table_name');
        ELSE
          SET @sql_stmt = CONCAT(@sql_stmt, '
            LEFT OUTER JOIN
             (SELECT isc4.table_schema,
                     isc4.table_name,
                     IF(((isc4.table_name LIKE "%_log") 
                          AND (isc4.column_name LIKE "log_%")) 
                         OR (isc4.table_name NOT LIKE "%_log"), 
                         isc4.column_name, 
                         NULL
                       )  AS dtm_column_name
                FROM ', LINK_TMP_SCHEMA_NAME, '.db2_information_schema_columns  isc4
               WHERE isc4.column_name IN (''', MDF_DTM_COL_NAME, ''', 
                                          ''', LAST_MOD_TIME_COL_NAME, ''',
                                          ''', LOG_CRT_DTM_COL_NAME, ''',
                                          ''', LOG_MDF_DTM_COL_NAME, '''
                                         )
                 AND IF(((isc4.table_name LIKE "%_log") 
                          AND (isc4.column_name LIKE "log_%")) 
                         OR (isc4.table_name NOT LIKE "%_log"), 
                         1, 
                         NULL
                       )  IS NOT NULL
             )  q4
              ON isc.table_schema  = q4.table_schema
                AND isc.table_name = q4.table_name');
        END IF;
        SET @sql_stmt = CONCAT(@sql_stmt, '
           WHERE isc.table_schema = ''', src_schema_name_in, ''' 
             ');
        SET v_entry_name = 'isc.table_name';
        --
        -- Get WHERE clause [Ex.: "AND table_name NOT LIKE '%account' AND table_name NOT LIKE '%account_log'"]
        --
        SET v_table_clause = (SELECT elt.split_condition_string (v_entry_name, 
                                                                 in_table_list_in, 
                                                                 not_in_table_list_in, 
                                                                 like_table_list_in, 
                                                                 not_like_table_list_in, 
                                                                 list_delimiter_in)
                                                                );
        SET @sql_stmt = CONCAT(@sql_stmt, ' ', 
                               v_table_clause, @LF,
           '          GROUP BY shard_profile_id, host_alias, shard_number, isc.table_schema, isc.table_name', @LF,   -- remove duplicates if account_id and owner_account_id are in one table
           '          ORDER BY isc.table_schema, isc.table_name');

        IF debug_mode_in THEN
          SELECT CONCAT(@LF, CAST(@sql_stmt AS CHAR), @LF, ";", @LF) AS debug_sql;
        ELSE
          PREPARE query FROM @sql_stmt;
          EXECUTE query;
          DEALLOCATE PREPARE query;
          COMMIT;
        END IF; 
      
        -- Set NULL for Sharding table's schemas 
        IF (v_shard_schema_name = src_schema_name_in) THEN
          UPDATE elt.src_tables
             SET delta_schema_name = NULL,
                 dst_schema_name   = NULL,
                 dst_table_name    = NULL
           WHERE host_alias      = v_host_alias
             AND shard_number    = LPAD(CAST(v_shard_num AS CHAR), 2, '0')
             AND src_schema_name = v_shard_schema_name
             AND src_table_name  = v_shard_table_name;
        END IF;

      END IF;  -- IF @table_defined = 0 

      SET v_shard_num = v_shard_num + 1;

    END WHILE;  -- WHILE @src_shard_nums
    -- ================================

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

SELECT '====> Procedure ''populate_src_tables'' has been created' AS "Info:" FROM dual;
