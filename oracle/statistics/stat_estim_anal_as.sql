REM /**********************************************************/
REM  SCRIPT
REM    stat_estim_anal_as.sql
REM  TITLE
REM    Advanced analyze operations
REM  HINT
REM    Advanced analyze operations
REM  DESCRIPTION
REM    Performs advanced ANALYZE operations
REM  COMPATIBILITY
REM    805, 815, 816, 817, 901, 920
REM /**********************************************************/

PROMPT
ACCEPT ownr PROMPT "Schema name LIKE (Enter for <All>): "
ACCEPT name PROMPT "Object name LIKE (Enter for <All>): "
ACCEPT type PROMPT "Object type ((T)able, (I)ndex, (C)luster, Enter for <All>): "
PROMPT

PROMPT
PROMPT POSSIBLE ANALYZE ACTION:
PROMPT
PROMPT D  = delete statistics
PROMPT
PROMPT E  = estimate statistics
PROMPT ET = estimate statistics for table
PROMPT EI = estimate statistics for all indexes
PROMPT EL = estimate statistics for all indexed columns
PROMPT
PROMPT C  = compute statistics
PROMPT CT = compute statistics for table
PROMPT CI = compute statistics for all indexes
PROMPT CL = compute statistics for all indexed columns
PROMPT
PROMPT VS = validate structure
PROMPT VC = validate structure cascade
PROMPT LC = list chained rows
PROMPT

PROMPT
ACCEPT actn PROMPT "Statistics action: "
PROMPT

@../../util/_BEGIN

SET HEADING OFF
SET ECHO OFF
SET FEEDBACK OFF
SET PAGESIZE 0
SET LINESIZE 120
SET TRIMSPOOL ON

DEFINE ty = "UPPER('&&type%')"
DEFINE ac = "UPPER('&&actn')"
DEFINE ft = "DECODE(o.object_type, 'TABLE', 'FOR TABLE')"
DEFINE fi = "DECODE(o.object_type, 'TABLE', 'FOR ALL INDEXES')"
DEFINE fc = "DECODE(o.object_type, 'TABLE', 'FOR ALL INDEXED COLUMNS')"

SELECT 'ANALYZE '||o.object_type||' '||o.owner||'.'||o.object_name||&&LF||
    DECODE(&&ac,
        'D' , 'DELETE STATISTICS',
        'E' , 'ESTIMATE STATISTICS',
        'ET', 'ESTIMATE STATISTICS ' || &&ft,
        'EI', 'ESTIMATE STATISTICS ' || &&fi,
        'EC', 'ESTIMATE STATISTICS ' || &&fc,
        'C' , 'COMPUTE STATISTICS',
        'CT', 'COMPUTE STATISTICS '  || &&ft,
        'CI', 'COMPUTE STATISTICS '  || &&fi,
        'CC', 'COMPUTE STATISTICS '  || &&fc,
        'VS', 'VALIDATE STRUCTURE',
        'VC', 'VALIDATE STRUCTURE CASCADE',
        'LC', 'LIST CHAINED ROWS'
    ) || ';'
  FROM dba_objects o
 WHERE o.owner       NOT IN ('SYS', 'SYSTEM')
   AND o.owner       LIKE NVL(UPPER('&&ownr'), '%')
   AND o.object_name LIKE NVL(UPPER('&&name'), '%')
   AND o.object_type LIKE &&ty
   AND o.object_type IN ('TABLE', 'INDEX', 'CLUSTER')
ORDER BY o.owner, o.object_name
/

UNDEFINE ownr name type actn cr ty ac ft fi fc

@../../util/_END
