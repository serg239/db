REM
REM TUNING STATISTICS SCRIPT
REM
REM This script examines various V$ parameters. The script makes suggestions on  
REM modifications that can be made to your system if specific conditions exist. 
REM The report should be run after the system has been up for at least 10 hours 
REM and should be run on several occasions over a period of time to get a feel for 
REM what the real condition of the database is. A one-time sample run on an 
REM intactive system will not give an accurate picture of what is really occuring 
REM within the database.  
REM  
REM If the database is shut down on a nightly basis for backups, the script can be  
REM run just prior to shutdown each night to enable trending analysis.  
REM  
REM This script can be run on any platform but is tailored to evaluate an  
REM Oracle7.x database. The script assumes that you are running it from a DBA  
REM account where CATDBSYN.SQL has been run.  
REM 

@../../util/_BEGIN 
@../../util/_TITLE "SYSTEM STATISTICS FOR ORACLE7" 80 ""

SET HEADING OFF
SELECT 'LIBRARY CACHE STATISTICS:' FROM DUAL;  
 
TTITLE OFF  
 
SELECT 'PINS (# of times an item in the library cache was executed) = '||SUM(pins),  
       'RELOADS (# of library cache misses on execution steps) = '||SUM (reloads)||&&LF||&&LF,  
       'RELOADS / PINS * 100 = '||ROUND((SUM(reloads) / SUM(pins) * 100), 2)||'%' 
  FROM v$librarycache  
/  

PROMPT
PROMPT Increase memory until RELOADS is near 0 but watch out for paging/swapping.
PROMPT To increase library cache, increase SHARED_POOL_SIZE.
PROMPT  
PROMPT ** NOTE: Increasing SHARED_POOL_SIZE will increase the SGA size.  
PROMPT  
PROMPT Library Cache Misses indicate that the Shared Pool is not big  
PROMPT enough to hold the shared SQL area for all concurrently open cursors.  
PROMPT If you have no Library Cache misses (PINS = 0), you may get a small  
PROMPT increase in performance by setting CURSOR_SPACE_FOR_TIME = TRUE which  
PROMPT prevents ORACLE from deallocating a shared SQL area while an application  
PROMPT cursor associated with it is open.  
PROMPT  
PROMPT For Multi-threaded server, add 1K to SHARED_POOL_SIZE per user.  
PROMPT  
  
COLUMN xn1 FORMAT A50  
COLUMN xn2 FORMAT A50  
COLUMN xn3 FORMAT A50  
COLUMN xv1 NEW_VALUE xxv1 NOPRINT  
COLUMN xv2 NEW_VALUE xxv2 NOPRINT  
COLUMN xv3 NEW_VALUE xxv3 NOPRINT  
COLUMN d1  FORMAT A50  
COLUMN d2  FORMAT A50  
 
PROMPT
PROMPT HIT RATIO:  
PROMPT  
PROMPT Values Hit Ratio is calculated against:
 
SELECT LPAD(name, 20, ' ') || '  =  ' || value xn1, 
       value xv1  
  FROM v$sysstat  
 WHERE statistic# = 37  
/
 
SELECT LPAD(name, 20, ' ') || '  =  ' || value xn2, 
       value xv2   
  FROM v$sysstat  
 WHERE statistic# = 38  
/  
 
SELECT LPAD(name, 20, ' ') || '  =  ' || value xn3, 
       value xv3   
  FROM v$sysstat b  
 WHERE statistic# = 39  
/  
 
SET PAGESIZE 60  
 
SELECT 'Logical reads = db block gets + consistent gets ',  
       LPAD ('Logical Reads = ', 24, ' ') || TO_CHAR(&xxv1 + &xxv2) d1  
FROM DUAL  
/  
 
SELECT 'Hit Ratio = (logical reads - physical reads) / logical reads',
       LPAD('Hit Ratio = ', 24, ' ') ||  
       ROUND( (((&xxv2 + &xxv1) - &xxv3) / (&xxv2 + &xxv1)) * 100, 2 ) || '%' d2  
  FROM DUAL  
/  

PROMPT
PROMPT If the hit ratio is less than 60%-70%, increase the initialization  
PROMPT parameter DB_BLOCK_BUFFERS.
PROMPT
PROMPT ** NOTE: Increasing this parameter will increase the SGA size.  
PROMPT  
  
COLUMN name     FORMAT A30  
COLUMN gets     FORMAT 9,999,999  
COLUMN waits    FORMAT 9,999,999  
 
PROMPT
PROMPT ROLLBACK CONTENTION STATISTICS:  
PROMPT  
  
PROMPT GETS  = # of gets on the rollback segment header 
PROMPT WAITS = # of waits for the rollback segment header  
  
SET HEADING ON  
 
SELECT name, 
       waits, 
       gets  
  FROM v$rollstat, 
       v$rollname  
 WHERE v$rollstat.usn = v$rollname.usn  
/  
 
SET HEADING OFF  
 
SELECT 'The average of waits/gets is ' ||
       ROUND((SUM(waits) / SUM(gets)) * 100, 2) || '%.'  
  FROM v$rollstat  
/  
  
PROMPT  
PROMPT If the ratio of waits to gets is more than 1% or 2%, consider  
PROMPT creating more rollback segments.
PROMPT  
PROMPT Another way to gauge rollback contention is:  
  
COLUMN xn1 FORMAT 9999999  
COLUMN xv1 NEW_VALUE xxv1 NOPRINT  
 
SET HEADING ON  
 
SELECT class, 
       count  
  FROM v$waitstat  
 WHERE class IN ('system undo header',
                 'system undo block', 
                 'undo header',
                 'undo block')  
/  
 
SET HEADING OFF  
 
SELECT 'Total requests = ' || SUM(count) xn1, 
       SUM(count) xv1  
  FROM v$waitstat  
/  
 
SELECT 'Contention for system undo header = ' ||
       (ROUND(COUNT/(&xxv1 + 0.00000000001), 4)) * 100 || '%'  
  FROM v$waitstat  
 WHERE class = 'system undo header'  
/  
 
SELECT 'Contention for system undo block = ' ||  
       (ROUND(COUNT/(&xxv1 + 0.00000000001), 4)) * 100 || '%'  
  FROM v$waitstat  
 WHERE class = 'system undo block'  
/  
 
SELECT 'Contention for undo header = '||  
       (ROUND(COUNT/(&xxv1 + 0.00000000001), 4)) * 100 || '%'  
  FROM v$waitstat  
WHERE class = 'undo header'  
/  
 
SELECT 'Contention for undo block = ' ||  
       (ROUND(COUNT/(&xxv1 + 0.00000000001), 4)) * 100 || '%'  
  FROM v$waitstat  
WHERE class = 'undo block'  
/  
 
PROMPT  
PROMPT If the percentage for an area is more than 1% or 2%, consider creating
PROMPT more rollback segments. Note: This value is usually very small and has 
PROMPT been rounded to 4 places.  
PROMPT  

PROMPT
PROMPT REDO CONTENTION STATISTICS:  
PROMPT  
PROMPT The following shows how often user processes had to wait for space in  
PROMPT the redo log buffer:  
  
SELECT name || ' = ' || value|| &&LF  
  FROM v$sysstat  
 WHERE name = 'redo log space requests'  
/  
 
PROMPT  
PROMPT This value should be near 0. If this value increments consistently,  
PROMPT processes have had to wait for space in the redo buffer. If this  
PROMPT condition exists over time, increase the size of LOG_BUFFER in the  
PROMPT init.ora file in increments of 5% until the value nears 0.
PROMPT
PROMPT ** NOTE: Increasing the LOG_BUFFER value will increase total SGA size.  
PROMPT    
  
COLUMN name             FORMAT A15  
COLUMN gets             FORMAT 9999999  
COLUMN misses           FORMAT 9999999  
COLUMN immediate_gets   HEADING 'IMMED GETS' FORMAT 9999999  
COLUMN immediate_misses HEADING 'IMMED MISS' FORMAT 9999999  
COLUMN sleeps           FORMAT 999999  
 
PROMPT
PROMPT LATCH CONTENTION:  
PROMPT  
PROMPT GETS = # of successful willing-to-wait requests for a latch.
PROMPT MISSES = # of times an initial willing-to-wait request was unsuccessful.
PROMPT IMMEDIATE_GETS = # of successful immediate requests for each latch.  
PROMPT IMMEDIATE_MISSES = # of unsuccessful immediate requests for each latch.  
PROMPT SLEEPS = # of times a process waited and requests a latch after an  
PROMPT initial willing-to-wait request.
PROMPT  
PROMPT If the latch requested with a willing-to-wait request is not  
PROMPT available, the requesting process waits a short time and requests again.  
PROMPT If the latch requested with an immediate request is not available,  
PROMPT the requesting process does not wait, but continues processing.
PROMPT  
  
SET HEADING ON  
 
SELECT name,
       gets,
       misses,  
       immediate_gets,
       immediate_misses,
       sleeps  
  FROM v$latch  
 WHERE name IN ('redo allocation', 
                'redo copy')  
/  
 
SET HEADING OFF  
 
SELECT 'Ratio of MISSES to GETS: ' ||  
       ROUND((SUM(misses) / (SUM(gets) + 0.00000000001) * 100), 2) || '%'  
  FROM v$latch  
 WHERE name IN ('redo allocation', 
                'redo copy')  
/  
 
SELECT 'Ratio of IMMEDIATE_MISSES to IMMEDIATE_GETS: ' ||
       ROUND((SUM(immediate_misses) /  
       (SUM(immediate_misses + immediate_gets) + 0.00000000001) * 100), 2) || '%'  
  FROM v$latch  
 WHERE name IN ('redo allocation', 
                'redo copy')  
/  
 
PROMPT  
PROMPT If either ratio exceeds 1%, performance will be affected.  
PROMPT  
PROMPT Decreasing the size of LOG_SMALL_ENTRY_MAX_SIZE reduces the number of  
PROMPT processes copying information on the redo allocation latch.  
PROMPT  
PROMPT Increasing the size of LOG_SIMULTANEOUS_COPIES will reduce contention  
PROMPT for redo copy latches.  
  
SET HEADING ON  

PROMPT
PROMPT  
PROMPT GETHITRATIO AND PINHIT RATIO:  
PROMPT  
PROMPT GETHITRATIO is number of GETHTS/GETS. PINHIT RATIO is number of
PROMPT PINHITS/PINS - number close to 1 indicates that most objects requested
PROMPT for pinning have been cached. Pay close attention to PINHIT RATIO.  
  
COLUMN namespace    FORMAT A20      HEADING 'NAME'  
COLUMN gets         FORMAT 99999999 HEADING 'GETS'  
COLUMN gethits      FORMAT 99999999 HEADING 'GETHITS'  
COLUMN gethitratio  FORMAT 999.99   HEADING 'GET HIT|RATIO'  
COLUMN pins         FORMAT 9999999  HEADING 'PINHITS'  
COLUMN pinhitratio  FORMAT 999.99   HEADING 'PIN HIT|RATIO'  
 
SELECT namespace, gets, gethits, gethitratio, pins, pinhitratio  
FROM v$librarycache  
/  

PROMPT
PROMPT  
PROMPT THE DATA DICTIONARY CACHE:  
PROMPT  
PROMPT Consider keeping this below 5% to keep the data dictionary cache in  
PROMPT the SGA. Up the SHARED_POOL_SIZE to improve this statistic.
PROMPT
PROMPT **NOTE: Increasing the SHARED_POOL_SIZE will increase the SGA.  

COLUMN dictcache FORMAT 999.99 HEADING 'Dictionary Cache|Ratio %'  
 
SELECT SUM(getmisses) / (SUM(gets) + 0.00000000001) * 100 dictcache  
  FROM v$rowcache  
/  

PROMPT  
PROMPT SYSTEM EVENTS:  
PROMPT  
PROMPT Not sure of the value of this section yet but it looks interesting.    
 
COLUMN event            FORMAT A37          HEADING 'Event'  
COLUMN total_waits      FORMAT 99999999     HEADING 'Total|Waits'  
COLUMN time_waited      FORMAT 9999999999   HEADING 'Time Wait|In Hndrds'  
COLUMN total_timeouts   FORMAT 999999       HEADING 'Timeout'  
COLUMN average_wait     FORMAT 999999.999   HEADING 'Average|Time'   
 
SET PAGESIZE 999  
 
SELECT * FROM v$system_event  
/  

PROMPT
PROMPT THE SGA AREA ALLOCATION:  
PROMPT  
PROMPT This shows the allocation of SGA storage. Examine this before and  
PROMPT after making changes in the INIT.ORA file which will impact the SGA.  
 
COLUMN name FORMAT A40  
 
SELECT name, 
       bytes 
  FROM v$sgastat  
/  
 
SET HEADING OFF  
 
SELECT 'total of SGA                               ' || SUM(bytes)
  FROM v$sgastat  
/ 
   
SET HEADING ON  
SET PAGESIZE 110  
 
COLUMN name        FORMAT A55            HEADING 'Statistic Name'  
COLUMN value       FORMAT 9,999,999,999  HEADING 'Result'  
COLUMN statistic#  FORMAT 9999           HEADING 'Stat#' 
 
@../../util/_TITLE 'INSTANCE STATISTICS'  
   
PROMPT Below is a dump of the core Instance Statistics that are greater than 0.  
PROMPT Although there are a great many statistics listed, the ones of greatest  
PROMPT value are displayed in other formats throughout this report. Of interest
PROMPT here are the values for:  
PROMPT  
PROMPT cumulative logons  
PROMPT (# of actual connections to the DB since last startup - good  
PROMPT volume-of-use statistic)  
PROMPT 
PROMPT table fetch continued row  
PROMPT (# of chained rows - will be higher if there are a lot of long fields   
PROMPT if the value goes up over time, it is a good signaller of general   
PROMPT database fragmentation)  
PROMPT  
  
SELECT statistic#, 
       name, 
       value  
  FROM v$sysstat  
 WHERE value > 0  
/  
   
SET PAGESIZE 66  
SET SPACE 3
SET HEADING ON

PROMPT 
PROMPT
PROMPT MAIN RATIOS:
PROMPT
PROMPT Parse Ratio usually falls between 1.15 and 1.45. If it is higher, then  
PROMPT it is usually a sign of poorly written Pro* programs or unoptimized  
PROMPT SQL*Forms applications.  
PROMPT  
PROMPT Recursive Call Ratio will usually be between:  
PROMPT  
PROMPT   7.0 - 10.0 for tuned production systems  
PROMPT  10.0 - 14.5 for tuned development systems  
PROMPT  
PROMPT Buffer Hit Ratio is dependent upon RDBMS size, SGA size and  
PROMPT the types of applications being processed. This shows the %-age  
PROMPT of logical reads from the SGA as opposed to total reads - the  
PROMPT figure should be as high as possible. The hit ratio can be raised  
PROMPT by increasing DB_BUFFERS, which increases SGA size. By turning on  
PROMPT the "Virtual Buffer Manager" (db_block_lru_statistics = TRUE and  
PROMPT db_block_lru_extended_statistics = TRUE in the init.ora parameters),  
PROMPT you can determine how many extra hits you would get from memory as  
PROMPT opposed to physical I/O from disk.
PROMPT
PROMPT **NOTE: Turning these on will impact performance. One shift of
PROMPT statistics gathering should be enough to get the required information.
  
@../../util/_TITLE 'RATIOS FOR THIS INSTANCE'  
 
COLUMN pcc   HEADING 'Parse|Ratio'       FORMAT 99.99  
COLUMN rcc   HEADING 'Recsv|Cursr'       FORMAT 99.99  
COLUMN hr    HEADING 'Buffer|Ratio'      FORMAT 999,999,999.999  
COLUMN rwr   HEADING 'Rd/Wr|Ratio'       FORMAT 999,999.9  
COLUMN bpfts HEADING 'Blks per|Full TS'  FORMAT 999,999 
 
SELECT
    SUM(DECODE(a.name, 'parse count', value, 0)) /  
    SUM(DECODE(a.name, 'opened cursors cumulative', value, .00000000001)) pcc,  
    SUM(DECODE(a.name, 'recursive calls', value, 0)) /  
    SUM(DECODE(a.name, 'opened cursors cumulative', value, .00000000001)) rcc,  
    (1 - (SUM(DECODE(a.name, 'physical reads', value, 0)) /  
    SUM(DECODE(a.name, 'db block gets', value, .00000000001)) +  
    SUM(DECODE(a.name, 'consistent gets', value, 0))) * (-1)) hr,  
    SUM(DECODE(a.name, 'physical reads', value, 0)) /  
    SUM(DECODE(a.name, 'physical writes', value, .00000000001)) rwr,  
    (SUM(DECODE(a.name, 'table scan blocks gotten', value, 0)) -  
    SUM(DECODE(a.name, 'table scans (short tables)', value, 0)) * 4) /  
    SUM(DECODE(a.name, 'table scans (long tables)', value, .00000000001)) bpfts  
FROM v$sysstat a  
/

PROMPT
PROMPT TABLESPACE USAGE:
PROMPT
PROMPT This looks at overall I/O activity against individual files within
PROMPT a tablespace.
PROMPT  
PROMPT Look for a mismatch across disk drives in terms of I/O.
PROMPT  
PROMPT Also, examine the Blocks per Read Ratio for heavily accessed  
PROMPT TSs - if this value is significantly above 1 then you may have  
PROMPT full tablescans occurring (with multi-block I/O).
PROMPT  
PROMPT If activity on the files is unbalanced, move files around to balance  
PROMPT the load. Should see an approximately even set of numbers across files.
  
SET PAGESIZE 100  
SET SPACE 1  
 
COLUMN pbr       FORMAT 99999999  HEADING 'Physical|Blk Read'  
COLUMN pbw       FORMAT 999999    HEADING 'Physical|Blks Wrtn'  
COLUMN pyr       FORMAT 999999    HEADING 'Physical|Reads'  
COLUMN readtim   FORMAT 99999999  HEADING 'Read|Time'  
COLUMN name      FORMAT A39       HEADING 'DataFile Name'  
COLUMN writetim  FORMAT 99999999  HEADING 'Write|Time'  
 
@../../util/_TITLE 'TABLESPACE REPORT'
 
COMPUTE SUM OF f.phyblkrd, f.phyblkwrt ON REPORT  
 
SELECT fs.name name,
       f.phyblkrd pbr,
       f.phyblkwrt pbw, 
       f.readtim,
       f.writetim  
  FROM v$filestat f,
       v$datafile fs  
 WHERE f.file#  =  fs.file#  
 ORDER BY fs.name  
/
PROMPT
PROMPT   
PROMPT GENERATING WAIT STATISTICS:  
PROMPT  
PROMPT This will show wait stats for certain kernel instances.  This  
PROMPT may show the need for additional rbs, wait lists, db_buffers.
PROMPT

@../../util/_TITLE 'WAIT STATISTICS FOR THE INSTANCE'  
 
COLUMN class  HEADING 'Class Type'  
COLUMN count  HEADING 'Times Waited'  FORMAT 99,999,999 
COLUMN time   HEADING 'Total Times'   FORMAT 99,999,999  
 
SELECT class, 
       count, 
       time  
  FROM v$waitstat  
 WHERE count > 0  
 ORDER BY class  
/  
 
PROMPT  
PROMPT Look at the wait statistics generated above (if any). They will  
PROMPT tell you where there is contention in the system. There will  
PROMPT usually be some contention in any system - but if the ratio of  
PROMPT waits for a particular operation starts to rise, you may need to  
PROMPT add additional resource, such as more database buffers, log buffers,  
PROMPT or rollback segments.
  
@../../util/_TITLE 'ROLLBACK STATISTICS'    
SET LINESIZE 80  
 
COLUMN extents      FORMAT 999          HEADING 'Extents'  
COLUMN rssize       FORMAT 999,999,999  HEADING 'Size in|Bytes'  
COLUMN optsize      FORMAT 999,999,999  HEADING 'Optimal|Size'  
COLUMN hwmsize      FORMAT 99,999,999   HEADING 'High Water|Mark'  
COLUMN shrinks      FORMAT 9,999        HEADING 'Num of|Shrinks'  
COLUMN wraps        FORMAT 9,999        HEADING 'Num of|Wraps'  
COLUMN extends      FORMAT 999,999      HEADING 'Num of|Extends'  
COLUMN aveactive    FORMAT 999,999,999  HEADING 'Average size|Active Extents'  
COLUMN rownum       NOPRINT  
 
SELECT rssize,
       optsize,
       hwmsize,  
       shrinks,
       wraps,
       extends,
       aveactive  
  FROM v$rollstat  
 ORDER BY rownum  
/  
 
BREAK ON REPORT  
COMPUTE SUM OF gets waits writes ON REPORT  
 
SELECT rownum,
       extents,
       rssize,  
       xacts,
       gets,
       waits,
       writes  
  FROM v$rollstat  
 ORDER BY rownum  
/  
 
TTITLE OFF  
SET HEADING OFF  

PROMPT
PROMPT  
PROMPT SORT AREA SIZE VALUES:  
PROMPT  
PROMPT To make best use of sort memory, the initial extent of your Users  
PROMPT sort-work Tablespace should be sufficient to hold at least one sort  
PROMPT run from memory to reduce dynamic space allocation. If you are getting  
PROMPT a high ratio of disk sorts as opposed to memory sorts, setting  
PROMPT sort_area_retained_size = 0 in init.ora will force the sort area to be  
PROMPT released immediately after a sort finishes.  
 
COLUMN value FORMAT 999,999,999  
 
SELECT 'INIT.ORA sort_area_size: ' || value  
  FROM v$parameter  
 WHERE name LIKE 'sort_area_size' 
/ 
  
SELECT a.name,  
       value  
  FROM v$statname a,  
       v$sysstat  b
 WHERE a.statistic# = b.statistic#  
   AND a.name IN ('sorts (disk)',
                  'sorts (memory)',
                  'sorts (rows)')  
/  
  
SET HEADING ON  
SET SPACE 2  
 
@../../util/_TITLE 'TABLESPACE SIZING INFORMATION'
 
COLUMN tablespace_name  FORMAT A30            HEADING 'TS Name'  
COLUMN sbytes           FORMAT 9,999,999,999  HEADING 'Total Bytes'  
COLUMN fbytes           FORMAT 9,999,999,999  HEADING 'Free Bytes'  
COLUMN kount            FORMAT 999            HEADING 'Ext'  
 
COMPUTE SUM OF fbytes ON tablespace_name  
COMPUTE SUM OF sbytes ON tablespace_name  
COMPUTE SUM OF sbytes ON report  
COMPUTE SUM OF fbytes ON report  
 
BREAK ON REPORT  
 
SELECT a.tablespace_name,
       a.bytes sbytes,  
       SUM(b.bytes) fbytes,
       COUNT(*) kount  
  FROM dba_data_files a,
       dba_free_space b  
 WHERE a.file_id = b.file_id  
 GROUP BY a.tablespace_name, a.bytes  
 ORDER BY a.tablespace_name  
/  
 
SET LINESIZE 80  
 
PROMPT  
PROMPT A large number of Free Chunks indicates that the tablespace may need  
PROMPT to be defragmented and compressed.  
PROMPT  
  
SET HEADING OFF   
TTITLE OFF  
 
COLUMN value FORMAT 99,999,999,999  
 
SELECT 'TOTAL PHYSICAL READS:', 
       value  
  FROM v$sysstat  
 WHERE statistic# = 39  
/  
 
PROMPT  
PROMPT If you can significantly reduce physical reads by adding incremental  
PROMPT data buffers... do it.  To determine whether adding data buffers will  
PROMPT help, set db_block_lru_statistics = TRUE and
PROMPT db_block_lru_extended_statistics = TRUE in the init.ora parameters.  
PROMPT You can determine how many extra hits you would get from memory as  
PROMPT opposed to physical I/O from disk.
PROMPT
PROMPT **NOTE: Turning these on will impact performance. One shift of statistics
PROMPT gathering should be enough to get the required information.  
PROMPT  
  
@../../util/_END
