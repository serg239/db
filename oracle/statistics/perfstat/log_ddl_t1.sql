REM  SCRIPT
REM    log_ddl_t1.sql
REM  TITLE
REM    DDL Event Log
REM  HINT
REM    DDL Event Log
REM  # Script Description:
REM  =====================
REM    * "What changed in the Database?" 
REM    * Using Oracle's event trigger functionality, you can now create an event trigger 
REM    to deal with DDL changes. For this purpose, you have several events you can 
REM    trap for: CREATE, ALTER, DROP or the generic DDL. 
REM    * For example, if you wanted to log every DDL action performed on the database 
REM    into a table called DDL_Log, you can create a trigger on the database to log the activity.

@c:\wds_scripts\util\_BEGIN
@c:\wds_scripts\util\_TITLE "DDL EVENT LOG" 130 "log_ddl_t1.sql"

COLUMN user_name  FORMAT A16  HEADING "User Name"
COLUMN DDL_date   FORMAT A22  HEADING "Date"
COLUMN DDL_event  FORMAT A20  HEADING "Event"
COLUMN obj_type   FORMAT A16  HEADING "Obj Type"
COLUMN obj_owner  FORMAT A16  HEADING "Obj Owner"
COLUMN obj_name   FORMAT A30  HEADING "Obj Name"

SELECT user_name,
       TO_CHAR(DDL_date, 'MM/DD/YYYY HH24:MI:SS') DDL_date,
       DDL_event,
       obj_type,
       obj_owner,
       obj_name
  FROM perfstat.stats$ddl_log
 ORDER BY DDL_date DESC
/

@c:\wds_scripts\util\_END
