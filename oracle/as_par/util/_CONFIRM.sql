REM /**********************************************************/
REM  SCRIPT
REM    _CONFIRM.sql
REM  TITLE
REM    Embedded script to prompt user before an action.
REM  HINT
REM    Prompt user before an action
REM  NOTES
REM    First parameter is the word describing the action
REM    Example: @_CONFIRM "execute"
REM /**********************************************************/

PROMPT

ACCEPT dummy CHAR PROMPT "Press ENTER to &&1 or CTRL+C to cancel..." HIDE

UNDEFINE dummy
