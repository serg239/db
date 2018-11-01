/*
  Version:
    2011.11.12.01
  Script:
    08_create_proc_add_elt_shard.sql
  Description:
    Remove Shard and all Tables on Shard from ELT process.
  Input:
    * host_alias_in      - Host Alias    [db1|db2]
    * shard_number_in    - Shard Number  [01|02|...]
    * host_ip_address    - Host IP
    * host_port_num      - Port Number
    * debug_mode_in      - Debug Mode.
                         Values:
                           * TRUE  (1) - show SQL statements
                           * FALSE (0) - execute SQL statements
  Output:
    Error Code: 
      * 0   - Success
      * -2: common error
  Istall:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\08_create_proc_add_elt_shard.sql
  Usage (display SQL only):
    CALL elt.add_elt_shard (@err, 'db1', '02', 'dbtest-db1', '3306', FALSE);
    CALL elt.add_elt_shard (@err, 'db2', '11', 'dbtest-db2', '3306', FALSE);
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.add_elt_shard
$$

CREATE PROCEDURE elt.add_elt_shard
(
  OUT error_code_out      INTEGER,
   IN host_alias_in       VARCHAR(16),   -- [db1|db2]
   IN shard_number_in     VARCHAR(2),    -- [01|02|...]
   IN host_ip_address_in  VARCHAR(128), 
   IN host_port_num_in    VARCHAR(6), 
   IN debug_mode_in       BOOLEAN
)
BEGIN

  DECLARE v_db_user_name         VARCHAR(64); 
  DECLARE v_db_user_pwd          VARCHAR(64); 
  DECLARE v_shard_schema_name    VARCHAR(64);
  DECLARE v_shard_table_name     VARCHAR(64);
  DECLARE v_shard_table_alias    VARCHAR(8);
  DECLARE v_shard_column_name    VARCHAR(64);
  DECLARE v_db_alias             VARCHAR(16); 

  DECLARE shard_info_cur CURSOR
  FOR
    SELECT DISTINCT spf.db_user_name,
           spf.db_user_pwd,
           shard_schema_name,
           shard_table_name,
           shard_table_alias,
           shard_column_name,
           db_alias
      FROM elt.shard_profiles spf
     WHERE spf.host_alias = host_alias_in
       AND spf.status = 1;

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  exec:
  BEGIN

    SET error_code_out = -2;
    --
    -- Get default shard info 
    --
    OPEN shard_info_cur;
    FETCH shard_info_cur
    INTO v_db_user_name,
         v_db_user_pwd,
         v_shard_schema_name,
         v_shard_table_name,
         v_shard_table_alias,
         v_shard_column_name,
         v_db_alias;
    CLOSE shard_info_cur;

    -- ==============================
    -- ADD SHARD
    -- ==============================
    INSERT INTO elt.shard_profiles
    (
      host_alias,
      shard_number,
      host_ip_address,
      host_port_num,
      db_user_name,
      db_user_pwd,
      status,
      shard_schema_name,
      shard_table_name,
      shard_table_alias,
      shard_column_name,
      db_alias,
      created_by,
      created_at
    ) VALUES 
    (
      host_alias_in,
      shard_number_in,
      host_ip_address_in,
      host_port_num_in,
      v_db_user_name,
      v_db_user_pwd,
      1,
      v_shard_schema_name,
      v_shard_table_name,
      v_shard_table_alias,
      v_shard_column_name,
      v_db_alias,
      SUBSTRING_INDEX(CURRENT_USER, "@", 1),
      CURRENT_TIMESTAMP()
    );
    COMMIT;
    SET error_code_out = 0;
  END;  -- exec  
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END
$$

DELIMITER ;

SELECT '====> Procedure ''add_elt_shard'' has been created' AS "Info:" FROM dual;
