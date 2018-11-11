REM  SCRIPT
REM    log_errors_t1.sql
REM  TITLE
REM    Server Errors
REM  HINT
REM    Server Errors
REM  # Script Description:
REM  =====================
REM    The SERVERERROR trigger takes whatever server error was generated from Oracle PL/SQL 
REM    and places it into an Oracle table. Note below that by capturing the user ID and the time 
REM    of the error, the Oracle administrator can build an insert trigger on the 
REM    stats$servererror log table and immediately be notified via e-mail whenever a server error occurs.

@c:\wds_scripts\util\_BEGIN
@c:\wds_scripts\util\_TITLE "SERVER ERRORS" 140 "log_errors_t1.sql"

COLUMN error      FORMAT A30  HEADING "Error"
COLUMN datestamp  FORMAT A20  HEADING "Date"
COLUMN username   FORMAT A16  HEADING "User Name"
COLUMN osuser     FORMAT A16  HEADING "OS User"
COLUMN machine    FORMAT A20  HEADING "Machine"
COLUMN process    FORMAT A8   HEADING "Process"
COLUMN program    FORMAT A20  HEADING "Program" WRAP

SELECT error,
       TO_CHAR(datestamp, 'MM/DD/YYYY HH24:MI:SS')  datestamp,
       username, 
       osuser,
       machine,
       process,
       program
  FROM perfstat.stats$servererror_log
 ORDER BY datestamp DESC
/ 

@c:\wds_scripts\util\_END
