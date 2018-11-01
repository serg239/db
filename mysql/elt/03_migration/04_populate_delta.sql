/*
  Version:
    2011.11.02.01
  Script:
    04_populate_delta.sql
  Description:
    Populate DELTA tables by data from External Database(es) and APPEND DELTA data to STAGE tables (Staging Area).
  Usage:
    nohup mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> -e "CALL elt.get_elt_data (@err, 'DELTA', FALSE, FALSE)" > populate_delta.log &
    OR
    nohup mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\04_populate_delta.sql > populate_delta.log &
*/
SET @old_sql_mode = (SELECT @@SQL_MODE);
SET @@SQL_MODE = '';

SET @SCHEMA_TYPE = 'DELTA';

SELECT CONCAT('====> Schema ''', @SCHEMA_TYPE, ''':  Migration Started at ', CURRENT_TIMESTAMP()) AS "Info:" FROM dual;

-- ====================================
--  schema_type - Schema Type. Values: [STAGE|DELTA]
--  validate    - Validate Flag.
--  debug_mode  - Debug Mode
-- ====================================
CALL elt.get_elt_data (@err, @SCHEMA_TYPE, FALSE, FALSE);
-- ====================================

SET @SCHEMA_NAME = 'elt';
CALL elt.drop_tmp_tables (@err, @SCHEMA_NAME);

-- SET @SCHEMA_NAME = 'db_link';
-- CALL elt.drop_tmp_tables (@err, @SCHEMA_NAME);
 
SELECT CONCAT('====> Schema ''', @SCHEMA_TYPE, ''': Migration Finished at ', CURRENT_TIMESTAMP()) AS "Info:" FROM dual;

SET @@SQL_MODE = @old_sql_mode;
