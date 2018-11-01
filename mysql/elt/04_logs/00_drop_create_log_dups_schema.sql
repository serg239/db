/*
  Version:
    2011.11.15.01
  Script:
    00_drop_create_log_dups_schema.sql
  Description:
    Re(Create) "db_dup" schema.
  Usage:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\00_drop_create_log_dups_schema.sql
  Attn:
    Script will DROP ALL data from LOG_DUPS schema.
*/

SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
SET @@SESSION.SQL_MODE = '';

SET @LOG_DUPS_SCHEMA_NAME  = 'log_dups';

-- ====================================
-- DROP DB_DUP schema
-- ====================================
SET @v_schema_exists = FALSE;
SELECT TRUE 
  INTO @v_schema_exists
  FROM information_schema.schemata 
 WHERE schema_name = @LOG_DUPS_SCHEMA_NAME;

SET @sql_stmt = IF(@v_schema_exists = TRUE,
                   CONCAT('DROP SCHEMA ', @LOG_DUPS_SCHEMA_NAME),
                   CONCAT('SELECT "====> Schema ''', @LOG_DUPS_SCHEMA_NAME, ''' does not  exist" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- Show Message
SET @sql_stmt = IF(@v_schema_exists = TRUE,
                   CONCAT('SELECT "====> Schema ''', @LOG_DUPS_SCHEMA_NAME, ''' has been dropped" AS "Info:" FROM dual'),
                   'SELECT "====> OK" AS "Info:" FROM dual'
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- CREATE DB_DUP schema
-- ====================================
SET @v_schema_exists = FALSE;
SELECT TRUE 
  INTO @v_schema_exists
  FROM information_schema.schemata 
 WHERE schema_name = @LOG_DUPS_SCHEMA_NAME;

-- CREATE SCHEMA if not exists
SET @sql_stmt = IF(@v_schema_exists = FALSE,
                   CONCAT('CREATE SCHEMA ', @LOG_DUPS_SCHEMA_NAME, ' DEFAULT CHARACTER SET utf8 COLLATE utf8_bin'),
                   CONCAT('SELECT "====> Schema ''', @LOG_DUPS_SCHEMA_NAME, ''' already exists" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- Show Message
SET @sql_stmt = IF(@v_schema_exists = FALSE,
                   CONCAT('SELECT "====> Schema ''', @LOG_DUPS_SCHEMA_NAME, ''' has been created" AS "Info:" FROM dual'),
                   'SELECT "====> OK" AS "Info:" FROM dual'
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

SET @v_schema_exists = NULL;
SET @sql_stmt        = NULL;

COMMIT;

SET @@SESSION.SQL_MODE = @old_sql_mode;
