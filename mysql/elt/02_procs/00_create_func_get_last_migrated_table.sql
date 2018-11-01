/*
  Version:
    2011.11.12.01
  Script:
    00_create_func_get_last_migrated_table.sql
  Description:
    Get information about the last migrated table
  Input:
    * schema_name_in
    * table_name_in
  Output:
    * Concatenated string (table name; rows; duration)
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\00_create_func_get_last_migrated_table.sql
  Usage:
    SELECT elt.get_last_migrated_table() AS last_migrated_table;
  Result:
    +-----------------------------------------------------------------------------------------------------+
    | last_migrated_table                                                                                 |
    +-----------------------------------------------------------------------------------------------------+
    | DB: db2; Shard: 01; Table: oi_pkg; Rows=6,496,775; Duration=2,796sec; Finished: 2011-10-17 17:59:45 |
    +-----------------------------------------------------------------------------------------------------+
*/
DELIMITER $$

DROP FUNCTION IF EXISTS elt.get_last_migrated_table$$ 

CREATE FUNCTION elt.get_last_migrated_table ( )
RETURNS VARCHAR(128)
BEGIN

  DECLARE v_not_founded  BOOLEAN      DEFAULT FALSE;
  DECLARE v_tmp_str      VARCHAR(128) DEFAULT "";

  DECLARE last_migrated_table_cur CURSOR 
  FOR
  SELECT CONCAT("DB: ",        host_alias, 
                "; Shard: ",   shard_number, 
                "; Table: ",   src_table_name, 
                "; Rows=" ,    FORMAT(proc_rows, 0),
                "; Duration=", FORMAT(proc_duration, 0), 'sec',
                "; Finished: ", modified_at)
    FROM elt.control_downloads
    WHERE control_download_id = 
      (SELECT MAX(control_download_id) 
         FROM elt.control_downloads
        WHERE download_status = 1  
      );

  DECLARE CONTINUE HANDLER
  FOR NOT FOUND 
  SET v_not_founded = TRUE;

  DECLARE CONTINUE HANDLER 
  FOR SQLSTATE 'HY000'
  SET v_not_founded = TRUE;

  OPEN last_migrated_table_cur;
  
  IF NOT v_not_founded THEN
    FETCH last_migrated_table_cur 
     INTO v_tmp_str;
  END IF;

  CLOSE last_migrated_table_cur;

  RETURN v_tmp_str;

END$$ 

DELIMITER ; 

SELECT '====> Function ''get_last_migrated_table'' has been created' AS "Info:" FROM dual;
