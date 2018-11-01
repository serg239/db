/*
  Version:
    2011.11.12.01
  Script:
    09_create_proc_remove_elt_shard.sql
  Description:
    Add Shard and all Tables on Shard to ELT process.
  Input:
    * host_alias_in      - Host Alias    [db1|db2]
    * shard_number_in    - Shard Number  [01|02|...]
    * debug_mode_in      - Debug Mode.
                         Values:
                           * TRUE  (1) - show SQL statements
                           * FALSE (0) - execute SQL statements
  Output:
    error_code: 
      * 0   - Success
      * -2: common error
  Istall:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\09_create_proc_remove_elt_shard.sql
  Usage:
    CALL elt.remove_elt_shard (@err, 'db1', '02', FALSE);
    CALL elt.remove_elt_shard (@err, 'db2', '11', FALSE);
*/
DELIMITER $$

DROP PROCEDURE IF EXISTS elt.remove_elt_table
$$

CREATE PROCEDURE elt.remove_elt_table
(
  OUT error_code_out     INTEGER,
   IN host_alias_in      VARCHAR(16),   -- [db1|db2]
   IN shard_number_in    VARCHAR(2),    -- shard number
   IN debug_mode_in      BOOLEAN
)
BEGIN

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  exec:
  BEGIN
    SET error_code_out = -2;
    DELETE FROM elt.shard_profiles
     WHERE host_alias   = host_alias_in
       AND shard_number = shard_number_in
     ;
    COMMIT;
    SET error_code_out = 0;
  END;  -- exec  
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END
$$

DELIMITER ;

SELECT '====> Procedure ''remove_elt_shard'' has been created' AS "Info:" FROM dual;
