REM /**********************************************************/
REM  SCRIPT
REM    tbsp_usage_t2.sql
REM  TITLE
REM    Tablespaces usage
REM  HINT
REM    Tablespaces usage: by Datafile and Total
REM  DESCRIPTION
REM    Tablespace sizing
REM  COMPATIBILITY
REM    7.3, 8.0, 8.1
REM /**********************************************************/

REM Calculate database block size

@_HIDE

COLUMN value NOPRINT NEW_VALUE blk_size

SELECT value 
  FROM v$parameter
 WHERE name = 'db_block_size'
/

@_BEGIN
@_TITLE "TABLESPACES USAGE <BY DATAFILE>" 132 "tbsp_usage_t2.sql"

COLUMN tablespace   FORMAT A16            HEADING "Tablespace Name"
COLUMN file_name    FORMAT A60            HEADING "File Name"
COLUMN total        FORMAT 9,999,999.000  HEADING "Total (Mb)"
COLUMN used_mg      FORMAT 9,999,999.000  HEADING "Used (Mb)" 
COLUMN free_mg      FORMAT 9,999,999.000  HEADING "Free (Mb)"
COLUMN use_pct      FORMAT 999.00         HEADING "Pct Used"

BREAK ON tablespace ON REPORT

COMPUTE SUM OF total   ON REPORT
COMPUTE SUM OF used_mg ON REPORT
COMPUTE SUM OF free_mg ON REPORT

SELECT DECODE(x.online$, 1, x.name,
                         SUBSTR(RPAD(x.name, 14), 1, 14)||' OFF') tablespace,
       a.file_name,
       ROUND((f.blocks * &blk_size) / (1024*1024))                total, 
       NVL(ROUND(SUM(s.length * &blk_size) / (1024*1024), 3), 0)  used_mg,
       ROUND(((f.blocks * &blk_size) / (1024*1024)) 
        - NVL(SUM(s.length * &blk_size) / (1024*1024), 0), 3)     free_mg,
       ROUND(SUM(s.length * &blk_size) / (1024*1024)
        / ((f.blocks * &blk_size)  / (1024*1024)) * 100, 3)       use_pct
  FROM sys.dba_data_files a, 
       sys.uet$           s, 
       sys.file$          f, 
       sys.ts$            x
 WHERE x.ts#     = f.ts# 
   AND x.online$ IN (1, 2)  /* Online !! */
   AND f.status$ = 2        /* Online !! */
   AND f.ts#     = s.ts# (+)
   AND f.file#   = s.file# (+)
   AND f.file#   = a.file_id
 GROUP BY x.name, x.online$, f.blocks, a.file_name
/

@_TITLE "TABLESPACES USAGE <TOTAL>" 132 "tbsp_usage_t2.sql"

SELECT DECODE(x.online$, 1, x.name,
                         SUBSTR(RPAD(x.name, 14), 1, 14)||' OFF')   tablespace,
      'Total '                                                      file_name,
      ROUND(SUM(DISTINCT(f.blocks + (f.file# / 1000)) * &blk_size)
        / (1024 * 1024) ) total,
      NVL(ROUND(SUM(s.length * &blk_size) / (1024*1024), 3), 0)   used_mg,
      ROUND(SUM(DISTINCT(f.blocks + (f.file# / 1000)) * &blk_size)
        / (1024 * 1024)
        - NVL(SUM(s.length  * &blk_size) / (1024*1024), 0), 3)    free_mg,
    ROUND(((SUM(s.length * &blk_size) / (1024*1024))
        / (SUM(DISTINCT(f.blocks + (f.file# / 1000)) * &blk_size)
        / (1024 * 1024))) * 100, 3)                                 use_pct
  FROM sys.uet$   s, 
       sys.file$  f, 
       sys.ts$    x
 WHERE x.ts#     = f.ts#
   AND x.online$ IN (1, 2) /* Online !! */
   AND f.status$ = 2       /* Online !! */
   AND f.ts#     = s.ts# (+)
   AND f.file#   = s.file# (+)
GROUP BY x.name, 
         x.online$
ORDER BY 1
/

UNDEFINE blk_size

@_END
