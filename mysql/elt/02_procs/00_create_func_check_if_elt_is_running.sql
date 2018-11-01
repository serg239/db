/*
  Version:
    2011.12.11.01
  Script:
    00_create_func_check_if_elt_is_running.sql
  Description:
  Input:
    None
  Output:
    Result:
      * 0 - ELT process has been finished
      * 1 - ELT process has not finished (running)
    Error Code:
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\00_create_func_check_if_elt_is_running.sql
  Usage:
    SELECT elt.check_if_elt_is_running (@err);
  Notes:
*/
DELIMITER $$

DROP FUNCTION IF EXISTS elt.check_if_elt_is_running$$

CREATE FUNCTION elt.check_if_elt_is_running
(
  error_code_out INTEGER
)
RETURNS INTEGER
DETERMINISTIC
BEGIN
  DECLARE is_running TINYINT DEFAULT 0;
  SET error_code_out = -2;
  SELECT IF (COUNT(*) > 0, 1, 0)
    INTO is_running
    FROM elt.control_downloads
   WHERE TIMESTAMPDIFF (HOUR, control_end_dtm, CURRENT_TIMESTAMP) <= 24
     AND (download_status = 0
      OR append_status = 0);
  SET error_code_out = 0;
  RETURN is_running;
END$$

DELIMITER ;

SELECT '====> Function ''check_if_elt_is_running'' has been created' AS "Info:" FROM dual;
