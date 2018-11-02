REM /**********************************************************/
REM  SCRIPT
REM    _TITLE.sql
REM  TITLE
REM    The script builds a Report Heading for database reports.
REM  HINT
REM    Builds a Report Heading for database reports
REM  NOTES
REM    No
REM /**********************************************************/

COLUMN title_   NEW_VALUE head_title_   NOPRINT
COLUMN line_    NEW_VALUE head_line_    NOPRINT
COLUMN script_  NEW_VALUE head_script_  NOPRINT
COLUMN today_   NEW_VALUE current_date_ NOPRINT
COLUMN time_    NEW_VALUE current_time_ NOPRINT
COLUMN user_db_ NEW_VALUE current_user_ NOPRINT

SET PAGESIZE 0
SET LINESIZE &&2

SELECT UPPER('&1')         title_,
       RPAD('*', &&2, '*') line_,
       LOWER(DECODE(NVL('&3', ''), '', 'nodefined.sql', '&3'))||' ' script_
  FROM sys.dual
/  

@@_SET

TTITLE -
   LEFT   head_line_                SKIP -
   LEFT   "Date: "   current_date_  -
   RIGHT  current_user_             SKIP -
   LEFT   "Time: "   current_time_  -
   CENTER head_title_               -
   RIGHT  head_script_              SKIP -
   LEFT   head_line_                SKIP 1

SET HEADING OFF
SET TERMOUT OFF
SET PAGESIZE 0

SELECT TO_CHAR(SYSDATE, 'DD/MM/YYYY') today_,
       TO_CHAR(SYSDATE, 'HH24:MI')    time_,
       user||'@'||name||' '           user_db_
  FROM sys.dual,
       v$database
/

@@_SET
