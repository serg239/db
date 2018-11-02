REM /**********************************************************/
REM  SCRIPT
REM    _SET.sql 
REM  TITLE
REM    Standard and Nonstandard settings.
REM  HINT
REM    Standard and Nonstandard settings
REM  NOTES
REM    No
REM /**********************************************************/

REM *** Standard settings ***

SET SERVEROUTPUT ON SIZE 1000000
SET NEWPAGE   1
SET NUMWIDTH  12
SET TRIMSPOOL ON
SET HEADING   ON
SET TERMOUT   ON
SET ECHO      OFF 

REM *** Nonstandard settings ***

SET VERIFY   OFF 
SET FEEDBACK OFF 
SET RECSEP   OFF
SET PAGESIZE 9999 
SET LONG     64

COLUMN nl NEWLINE



