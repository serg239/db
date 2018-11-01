/*
  Version:
    2011.11.12.01
  Script:
    01_create_proc_create_info_link_tables.sql
  Description:
    Create FEDERATED tables in ELT schema to connect to information_schema 
    tables on a given host (default shard_number '01').
  Input:
    * host_alias          - Host Alias   [db1|db2]
    * debug_mode          - Debug Mode. Values:
                            * FALSE (0) - execute SQL statements
                            * TRUE  (1) - show SQL statements
  Output:
    * error_code:
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\01_create_proc_create_info_link_tables.sql
  Usage:
    CALL elt.create_info_link_tables (@err, 'db1', FALSE);  -- links to columns and indexes
    CALL elt.create_info_link_tables (@err, 'db2', FALSE);  -- links to columns and indexes
*/
DELIMITER $$ 

DROP PROCEDURE IF EXISTS elt.create_info_link_tables$$ 

CREATE PROCEDURE elt.create_info_link_tables
(
 OUT error_code_out  INTEGER,
  IN host_alias_in   VARCHAR(16),   -- Host Alias   [db1|db2]
  IN debug_mode_in   BOOLEAN
) 
BEGIN

  DECLARE v_host_alias    VARCHAR(16) DEFAULT host_alias_in;
  DECLARE v_host_conn_str VARCHAR(255);
  DECLARE v_tbl_conn_str  VARCHAR(255);
  --
  -- Shard Information
  --
  DECLARE shard_info_cur CURSOR
  FOR
    SELECT CONCAT('mysql://', spf.db_user_name, ':', spf.db_user_pwd, '@', spf.host_ip_address, ':', spf.host_port_num) AS host_conn_str
      FROM elt.shard_profiles   spf
     WHERE spf.host_alias = v_host_alias
       AND shard_number   = '01'          -- default 
       AND spf.status     = 1;            -- active shard

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET @LF = CHAR(10);

  exec:
  BEGIN
    
    SET error_code_out = -2;

    OPEN shard_info_cur;   -- F(v_host_alias)
    FETCH shard_info_cur
     INTO v_host_conn_str;
    CLOSE shard_info_cur;
    
    IF (v_host_conn_str IS NOT NULL) THEN
    
      -- ==============================
      -- Columns
      -- ==============================
      SET error_code_out = -3;
      SET v_tbl_conn_str = CONCAT(CHAR(39), v_host_conn_str, '/information_schema/columns', CHAR(39));
      
      SET @sql_stmt = CONCAT('CREATE TABLE IF NOT EXISTS elt.', v_host_alias, '_information_schema_columns 
      (  
        table_schema      VARCHAR(64) NOT NULL DEFAULT "",
        table_name        VARCHAR(64) NOT NULL DEFAULT "",
        column_name       VARCHAR(64) NOT NULL DEFAULT "",
        column_type       LONGTEXT    NOT NULL,
        column_key        VARCHAR(3)  NOT NULL DEFAULT "",
        is_nullable       VARCHAR(3)  NOT NULL DEFAULT "",
        column_default    LONGTEXT,
        ordinal_position  BIGINT(21)  UNSIGNED NOT NULL DEFAULT "0"
      ) 
      ENGINE          = FEDERATED
      DEFAULT CHARSET = utf8
      CONNECTION      = ', v_tbl_conn_str);

      IF debug_mode_in THEN
        SELECT CONCAT(@LF, 
                      CAST(@sql_stmt AS CHAR), @LF, 
                      ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
        SELECT CONCAT('====> Table ''', v_host_alias, '_information_schema_columns'' has been created') AS "Info:" FROM dual;
      END IF;
      
      -- ==============================
      -- Indexes
      -- ==============================
      SET error_code_out = -4;
      SET v_tbl_conn_str = CONCAT(CHAR(39), v_host_conn_str, '/information_schema/statistics', CHAR(39));
      
      SET @sql_stmt = CONCAT('CREATE TABLE IF NOT EXISTS elt.', v_host_alias, '_information_schema_indexes
      (
        index_schema      VARCHAR(64) NOT NULL DEFAULT "",
        table_name        VARCHAR(64) NOT NULL DEFAULT "",
        index_name        VARCHAR(64) NOT NULL DEFAULT "",
        non_unique        BIGINT(1)   NOT NULL DEFAULT "0",
        column_name       VARCHAR(64) NOT NULL DEFAULT "",
        seq_in_index      BIGINT(2)   NOT NULL DEFAULT "0"
      ) 
      ENGINE          = FEDERATED 
      DEFAULT CHARSET = utf8
      CONNECTION      = ', v_tbl_conn_str);

      IF debug_mode_in THEN
        SELECT CONCAT(@LF, 
                      CAST(@sql_stmt AS CHAR), @LF, 
                      ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
        SELECT CONCAT('====> Table ''', v_host_alias, '_information_schema_indexes'' has been created') AS "Info:" FROM dual;
      END IF;
    
/*
      -- ==============================
      -- Processes
      -- ==============================
      SET v_tbl_conn_str = CONCAT(CHAR(39), v_host_conn_str, '/information_schema/processlist', CHAR(39));
      
      SET @sql_stmt = CONCAT('CREATE TABLE IF NOT EXISTS elt.', v_host_alias, '_information_schema_processes
      (
        id       BIGINT(4)   NOT NULL DEFAULT "0",
        user     VARCHAR(16) NOT NULL DEFAULT "",
        host     VARCHAR(64) NOT NULL DEFAULT "",
        db       VARCHAR(64),
        command  VARCHAR(16) NOT NULL DEFAULT "",
        time     INTEGER(7)  NOT NULL DEFAULT "0"
      ) 
      ENGINE          = FEDERATED 
      DEFAULT CHARSET = utf8
      CONNECTION      = ', v_tbl_conn_str);

      IF debug_mode_in THEN
        SELECT CONCAT(@LF, 
                      CAST(@sql_stmt AS CHAR), @LF, 
                      ";", @LF) AS debug_sql;
      ELSE
        PREPARE query FROM @sql_stmt;
        EXECUTE query;
        DEALLOCATE PREPARE query;
        SELECT CONCAT('====> Table ''', v_host_alias, '_information_schema_processes'' has been created') AS "Info:" FROM dual;
      END IF;
*/
    END IF;  -- IF (v_host_conn_str IS NOT NULL)
    SET error_code_out = 0; 
  END;  -- exec:  
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END$$

DELIMITER ;

SELECT '====> Procedure ''create_info_link_tables'' has been created' AS "Info:" FROM dual;
