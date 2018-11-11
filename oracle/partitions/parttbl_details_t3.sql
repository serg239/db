REM /**********************************************************/
REM  SCRIPT
REM    parttbl_detals_at3.sql
REM  TITLE
REM    Partitioned Tables and Indexes
REM  HINT
REM    This script lists details of table and index partitions.
REM  COMMENTS
REM    # Query Tables and Views:
REM    =========================
REM    SYS.ALL_TAB_PARTITIONS   - Provides Partition-Level Partitioning information, Partition Storage Parameters,
REM                               and Partition Statistics collected by ANALYZE Statements for Partitions accessible
REM                               to the current user.
REM    SYS.ALL_PART_TABLES      - Provides Object-Level Partitioning information for Partitioned Tables
REM                               accessible to the current user.
REM    SYS.ALL_PART_KEY_COLUMNS - Describes the Partitioning Key Columns for Partitioned Objects accessible
REM                               to the current user.
REM    SYS.ALL_IND_PARTITIONS   - Describes, for each Index Partition accessible to the current user, the
REM                               Partition-Level Partitioning information, the Storage Parameters for the Partition,
REM                               and various Partition Statistics collected by ANALYZE Statements.
REM    SYS.ALL_PART_INDEXES     - Provides Object-Level Partitioning information for All Partitioned Indexes
REM                               accessible to the current user.
REM    # Links:
REM    ========
REM    http://otn.oracle.com/docs/products/oracle9i/doc_library/release2/server.920/a96536/ch2142.htm#116213
REM    http://otn.oracle.com/docs/products/oracle9i/doc_library/release2/server.920/a96536/ch2101.htm#115819
REM    http://otn.oracle.com/docs/products/oracle9i/doc_library/release2/server.920/a96536/ch299.htm#115797
REM    http://otn.oracle.com/docs/products/oracle9i/doc_library/release2/server.920/a96536/ch249.htm#115175
REM    http://otn.oracle.com/docs/products/oracle9i/doc_library/release2/server.920/a96536/ch298.htm#115775
REM  NOTES
REM    * Table Name         - Table name
REM    * Partition Name     - Partition name
REM    * Partitioning Type  - Type of partitioning:
REM                           * RANGE
REM                           * HASH
REM                           * SYSTEM
REM                           * LIST
REM                           * UNKNOWN
REM    * High Value         - Partition bound value expression
REM    * Partition Position - Position of the partition within the table
REM    * Tablespace Name    - Name of the tablespace containing the partition
REM  COMPATIBILITY
REM    805, 815, 816, 817, 901, 920
REM /**********************************************************/

PROMPT
ACCEPT ownr PROMPT "Schema owner: (Enter for <All>): "
PROMPT
 
@C:\wds_scripts\util\_BEGIN
@C:\wds_scripts\util\_TITLE "01. PARTITIONED TABLES" 160 "parttbl_detals_at3.sql"

COLUMN table_name          FORMAT A24      HEADING "Table Name"
COLUMN partition_name      FORMAT A24      HEADING "Partition Name"
COLUMN partitioning_type   FORMAT A7       HEADING "PartType"
COLUMN high_value          FORMAT A32      HEADING "High Value"  TRUNC
COLUMN partition_position  FORMAT 999999   HEADING "PartPos"
COLUMN tablespace_name     FORMAT A16      HEADING "Tablespace Name"

SELECT atbpt.table_name,
       atbpt.partition_name,
       apttb.partitioning_type,
       atbpt.high_value,
       atbpt.partition_position,
       atbpt.tablespace_name
  FROM all_tab_partitions atbpt, 
       all_part_tables    apttb
 WHERE atbpt.table_owner = apttb.owner
   AND atbpt.table_name  = apttb.table_name
   AND apttb.owner       LIKE NVL(UPPER('&ownr'), '%')
 ORDER BY atbpt.table_name, atbpt.partition_position
 
/ 

@C:\wds_scripts\util\_TITLE "02. PARTITIONED TABLE COLUMNS" 100 "parttbl_detals_at3.sql"

COLUMN name             FORMAT A30   HEADING "Object Name"
COLUMN object_type      FORMAT A15   HEADING "Object Type"
COLUMN column_name      FORMAT A20   HEADING "Column Name"
COLUMN column_position  FORMAT 9999  HEADING "ColPos"

SELECT name,
       object_type,
       column_name,
       column_position 
  FROM all_part_key_columns
 WHERE owner LIKE NVL(UPPER('&ownr'), '%')
 ORDER BY name, column_position
/ 

@C:\wds_scripts\util\_TITLE "03. PARTITIONED INDEXES" 120 "parttbl_detals_at3.sql"

COLUMN index_name         FORMAT A30    HEADING "Index Name"
COLUMN locality           FORMAT A3     HEADING "L/G"
COLUMN alignment          FORMAT A5     HEADING "Prfxd"
COLUMN partition_name     FORMAT A30    HEADING "Partition Name"
COLUMN high_value         FORMAT A8     HEADING "High Value"
COLUMN partition_position FORMAT 99999  HEADING "PartPos"
COLUMN status             FORMAT A8     HEADING "Status"
COLUMN tablespace_name    FORMAT A16    HEADING "Tablespace Name"

SELECT aidpt.index_name, 
       DECODE(aptid.locality, 'LOCAL',  'L', 
                              'GLOBAL', 'G',
                              aptid.locality
             ) locality,
       DECODE(aptid.alignment, 'NON_PREFIXED', 'NP', 
                               'PREFIXED',     'P',
                               aptid.alignment
             ) alignment,
       aidpt.partition_name,
       aidpt.high_value,
       aidpt.partition_position,
       aidpt.status,
       aidpt.tablespace_name
  FROM all_ind_partitions aidpt, 
       all_part_indexes   aptid
 WHERE aidpt.index_name  = aptid.index_name 
   AND aidpt.index_owner = aptid.owner
   AND aptid.owner       LIKE NVL(UPPER('&ownr'), '%')
 ORDER BY aidpt.index_name, aidpt.partition_position
/

UNDEFINE ownr

@C:\wds_scripts\util\_END

