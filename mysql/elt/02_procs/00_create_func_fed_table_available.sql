/*
  Version:
    2011.11.12.01
  Script:
    00_create_func_fed_table_available.sql
  Description:
    Check if FEDERATED table available
  Input:
    * host_alias
    * shard_number
    * src_schema_name
    * src_table_name
  Output:
    * TRUE  (1) - table is available
    * FALSE (0) - table is not available
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\00_create_func_fed_table_available.sql
  Usage:
    SELECT elt.fed_table_available('db1', '01', 'account', 'account_log') AS tbl_available;
  Result:  
    +---------------+
    | tbl_available |
    +---------------+
    |             1 |
    +---------------+
  Usage:
    SELECT elt.fed_table_available('db1', '01', 'account', 'account_status') AS tbl_available;
  Result:  
    +---------------+
    | tbl_available |
    +---------------+
    |             0 |
    +---------------+
*/
DELIMITER $$

DROP FUNCTION IF EXISTS elt.fed_table_available$$ 

CREATE FUNCTION elt.fed_table_available
( 
  host_alias_in       VARCHAR(16),     -- Ex.: 'db1'
  shard_number_in     VARCHAR(2),      -- Ex.: '01'    
  src_schema_name_in  VARCHAR(64),     -- Ex.: 'account'
  src_table_name_in   VARCHAR(64)      -- Ex.: 'account_log'
)
RETURNS BOOLEAN
BEGIN

  DECLARE LINK_SCHEMA_NAME  VARCHAR(16) DEFAULT 'db_link';
 
  DECLARE v_table_name      VARCHAR(64);
  DECLARE v_tmp_int         INTEGER;
  DECLARE v_not_available   BOOLEAN DEFAULT FALSE;

  DECLARE tbl_avaiable_cur CURSOR 
  FOR
  SELECT COUNT(*)
    FROM information_schema.tables
   WHERE table_schema = LINK_SCHEMA_NAME
     AND table_name   = v_table_name;

  DECLARE CONTINUE HANDLER 
  FOR SQLSTATE 'HY000'
  SET v_not_available = TRUE;

  -- table name
  SET v_table_name = CONCAT(host_alias_in, '_',
                            shard_number_in, '_',
                            src_schema_name_in, '_',
                            src_table_name_in
                           ); 

  OPEN tbl_avaiable_cur;
  IF v_not_available THEN
    CLOSE tbl_avaiable_cur;
    RETURN FALSE;
  ELSE
    FETCH tbl_avaiable_cur INTO v_tmp_int;
    CLOSE tbl_avaiable_cur;
    RETURN (v_tmp_int > 0);
  END IF;
END$$ 

DELIMITER ; 

SELECT '====> Function ''fed_table_available'' has been created' AS "Info:" FROM dual;
