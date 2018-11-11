REM  SCRIPT
REM    log_user_event_t1.sql
REM  TITLE
REM    User Event Log
REM  HINT
REM    User Event Log
REM  # Script Description:
REM  =====================
REM    * One of things that some organizations find useful is to determine the length of time 
REM    individuals spend being connected to the database. 
REM    You can also gauge usage patterns for the database and track logon/logoff trends. 
REM    While this may seem somewhat Big Brother-ish, for many organizations this is not 
REM    an option and may be a legal requirement. 
REM    * The AFTER LOGON and BEFORE LOGOFF events can have triggers created on them to log 
REM    this activity for your users. You can capture when the user logs on and off, which 
REM    instance (in a parallel server environment) the user logged on 
REM    to, what IP address the client is connecting from and other information. 

@c:\wds_scripts\util\_BEGIN
@c:\wds_scripts\util\_TITLE "USER EVENT LOG" 80 "log_user_event_t1.sql"

COLUMN user_name     FORMAT A16    HEADING "User Name"
COLUMN event_action  FORMAT A12    HEADING "Action"
COLUMN event_date    FORMAT A22    HEADING "Date"
COLUMN IP_address    FORMAT A16    HEADING "IP Address"
COLUMN instance_num  FORMAT 99999  HEADING "Inst#"
 
SELECT user_name, 
       event_action, 
       TO_CHAR(event_date, 'MM/DD/YYYY HH24:MI:SS')  event_date,
       IP_address,
       instance_num
  FROM perfstat.stats$user_conn
 ORDER BY event_date DESC
/ 

@c:\wds_scripts\util\_END
