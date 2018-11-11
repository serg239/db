REM /**********************************************************/
REM  SCRIPT
REM    tbsp_report_t1.sql
REM  TITLE
REM    Tablespace Report
REM  HINT
REM    Tablespace Report from SQL*Plus
REM  COMMENTS
REM    # Query Tables and Views:
REM    =========================
REM    SYS.DBA_TABLESPACES - Describes all Tablespaces in the database.
REM    SYS.DBA_DATA_FILES  - Describes Database Files.
REM    SYS.DBA_TEMP_FILES  - Describes all Temporary Files (tempfiles) in the database.
REM    SYS.DBA_FREE_SPACE  - Lists the Free Extents in All Tablespaces.
REM    V$TEMP_SPACE_HEADER - Displays Aggregate information per File per Temporary Tablespace regarding
REM                          how much Space is currently being Used and how much is Free as per the Space Header.
REM    # Links:
REM    ========
REM    http://otn.oracle.com/docs/products/oracle9i/doc_library/release2/server.920/a96536/ch2374.htm#REFRN2328
REM    http://otn.oracle.com/docs/products/oracle9i/doc_library/release2/server.920/a96536/ch2212.htm#116679
REM    http://otn.oracle.com/docs/products/oracle9i/doc_library/release2/server.920/a96536/ch2375.htm#117249
REM    http://otn.oracle.com/docs/products/oracle9i/doc_library/release2/server.920/a96536/ch2235.htm#116748
REM    http://otn.oracle.com/docs/products/oracle9i/doc_library/release2/server.920/a96536/ch3223.htm#110458
REM  NOTES
REM    * Tablespace Name - Tablespace name
REM    * Type            - Tablespace contents:
REM                        * PERMANENT
REM                        * TEMPORARY
REM    * Ext Mgmt        - Extent management tracking:
REM                        * DICTIONARY
REM                        * LOCAL
REM    * Size Mb         - Size of tablespace
REM    * Free Mb         - Free space in Mbytes
REM    * Used Mb         - Used space in Mbytes
REM    * Status          - Tablespace status:
REM                        * ONLINE
REM                        * OFFLINE
REM                        * READ ONLY
REM  DESCRIPTION
REM    Lists all the tablespace names in the database with their type (whether permanent or temporary), 
REM    extent management (whether local or dictionary), sizes, and status (online, offline, read-only). 
REM  COMPATIBILITY
REM    805, 815, 816, 817, 901, 920
REM /**********************************************************/

@c:\wds_scripts\util\_BEGIN
@c:\wds_scripts\util\_TITLE "TABLESPACE REPORT" 104 "tbsp_report_t1.sql"

COLUMN tsname   FORMAT A24          HEADING "Tablespace Name"
COLUMN type     FORMAT A11          HEADING "Type"
COLUMN ext_mgt  FORMAT A12          HEADING "Ext Mgmt"
COLUMN status   FORMAT A9           HEADING "Status"
COLUMN size_mb  FORMAT 999,999,999  HEADING "Size (MB)"
COLUMN free_mb  FORMAT 999,999,999  HEADING "Free (MB)"
COLUMN used_mb  FORMAT 999,999,999  HEADING "Used (MB)"

COMPUTE SUM LABEL 'Total'         OF size_mb ON REPORT
COMPUTE SUM LABEL 'Total Free MB' OF free_mb ON REPORT
COMPUTE SUM LABEL 'Total Used MB' OF used_mb ON REPORT

BREAK ON REPORT

SELECT a.tablespace_name          tsname,
       a.contents                 type,
       a.extent_management        ext_mgt,
       b.bytes/(1024*1024)        size_mb,
       (c.free_bytes/(1024*1024)) free_mb,
       (b.bytes-c.free_bytes)/(1024*1024) used_mb,
       a.status                   status              
  FROM dba_tablespaces a,
   (SELECT tablespace_name, 
           SUM(bytes)   bytes
      FROM dba_data_files
      GROUP BY tablespace_name 
    UNION
    SELECT tablespace_name, 
           SUM(bytes)   bytes
       FROM dba_temp_files
      GROUP BY tablespace_name
    )  b,
    (SELECT dfs.tablespace_name, 
            SUM(dfs.bytes)  free_bytes,
            (SUM(ddf.bytes) - SUM(dfs.bytes)) used_bytes
       FROM dba_free_space  dfs, 
            dba_data_files  ddf
       WHERE dfs.tablespace_name = ddf.tablespace_name
       GROUP BY dfs.tablespace_name
    UNION
    SELECT tablespace_name, 
           SUM(bytes_free)  free_bytes, 
           SUM(bytes_used)  used_bytes  
      FROM v$temp_space_header
     GROUP BY tablespace_name
    )  c
 WHERE a.tablespace_name = b.tablespace_name
   AND c.tablespace_name = a.tablespace_name
   AND c.tablespace_name = b.tablespace_name
 ORDER BY 1
/

@c:\wds_scripts\util\_END
