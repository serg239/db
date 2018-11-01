/*
  Version:
    2011.10.31.01
  Script:
    01_create_info_link_tables.sql
  Description:
    Create FED tables to link to SRC information_schema tables.
  Usage:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\01_create_info_link_tables.sql
  Notes:
    CALL elt.create_info_link_tables (@err, 'db1', FALSE);
*/

SET @old_sql_mode = (SELECT @@SQL_MODE);
SET @@SQL_MODE = '';

SET @DB1_HOST_ALIAS = 'db1';
SET @DB2_HOST_ALIAS = 'db2';

-- ============================================================================
--                         L I N K  (F E D)  T A B L E S
-- ============================================================================

-- ====================================
-- DB1
-- ====================================
CALL elt.create_info_link_tables (@err, @DB1_HOST_ALIAS, FALSE);

-- ====================================
-- DB2
-- ====================================
CALL elt.create_info_link_tables (@err, @DB2_HOST_ALIAS, FALSE);

SET @@SQL_MODE = @old_sql_mode;

