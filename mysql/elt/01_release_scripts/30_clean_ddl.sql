/*
  Version:
    2012.01.16.01
  Script:
    30_clean_ddl.sql
  Description:
    * Modify Auto_Incremental fields 
    * Drop Foreign Keys 
      in DB tables of DB3 STAGING area
  Usage:
    CALL mysql.clean_ddl (@err, TRUE);   -- display SQL only
    CALL mysql.clean_ddl (@err, FALSE);  -- execute statements
*/
SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
SET @@SESSION.SQL_MODE = '';

SET @DEBUG_MODE = FALSE;

CALL mysql.clean_ddl (@err_num, @DEBUG_MODE);

SET @sql_stmt = IF(@err_num <> 0,
                   CONCAT('SELECT "====> Could not update AI fields and drop FK constraints. Error = ', @err_num, '" AS "Error:" FROM dual'),
                   CONCAT('SELECT "====> The AI fields have been updated and FK constraints have been dropped successfully" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

COMMIT;

SET @@SESSION.SQL_MODE = @old_sql_mode;
