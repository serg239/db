**********************************************************
CHECK SIZE AND PARAMETERS
**********************************************************

@tbsp_usage_t2

Tablespace Name  File Name                                                        Total (Mb)      Used (Mb)      Free (Mb) Pct Used
---------------- ------------------------------------------------------------ -------------- -------------- -------------- --------
CVM_200309_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200309_indx.dbf                  100.000         90.043          9.957    90.04
CVM_200310_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200310_indx.dbf                  150.000        127.055         22.945    84.70
CVM_200311_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200311_indx.dbf                  150.000        137.082         12.918    91.39
CVM_200312_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200312_indx.dbf                  170.000        167.430          2.570    98.49
CVM_200401_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200401_indx.dbf                  300.000        173.059        126.941    57.69
CVM_200402_INDX  /dbbig/oracle/oradata/cvtest/cvm/cvm_200402_indx.dbf                300.000        154.906        145.094    51.64
CVM_200403_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200403_indx.dbf                  180.000        144.141         35.859    80.08

SELECT partition_name, 
       ini_trans, 
       max_trans, 
       initial_extent, 
       next_extent, 
       min_extent, 
       max_extent, 
       pct_increase, 
       freelists, 
       freelist_groups, 
       pct_free, 
       logging 
  FROM dba_ind_partitions 
 WHERE index_owner = 'CVM_ADMIN' 
   AND index_name  = 'T_TRANS_MEMO#TUID_DTS_PIDX'
 ORDER BY 1  
/   

PARTITION_NAME                    INI_TRANS    MAX_TRANS INITIAL_EXTENT  NEXT_EXTENT   MIN_EXTENT   MAX_EXTENT PCT_INCREASE    FREELISTS FREELIST_GROUPS     PCT_FREE LOGGING
------------------------------ ------------ ------------ -------------- ------------ ------------ ------------ ------------ ------------ --------------- ------------ -------
T_INDX_TRANS_MEMO200309                   2          255          12288        12288            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200310                   2          255          12288        12288            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200311                   2          255          12288        12288            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200312                   2          255           8192         8192            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200401                   2          255           8192         8192            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200402                   2          255        1048576      1048576            1   2147483645            0            7               1            5 YES
T_INDX_TRANS_MEMO200403                   2          255          65536         8192            1   2147483645            0            2               1            5 NO

DROP INDEX cvm_admin.t_trans_memo#tuid_dts_pidx
/
Index dropped.

CVM_200309_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200309_indx.dbf                  100.000         90.031          9.969    90.03
CVM_200310_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200310_indx.dbf                  150.000        127.043         22.957    84.70
CVM_200311_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200311_indx.dbf                  150.000        137.070         12.930    91.38
CVM_200312_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200312_indx.dbf                  170.000        167.422          2.578    98.48
CVM_200401_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200401_indx.dbf                  300.000        173.051        126.949    57.68
CVM_200402_INDX  /dbbig/oracle/oradata/cvtest/cvm/cvm_200402_indx.dbf                300.000        153.891        146.109    51.30
CVM_200403_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200403_indx.dbf                  180.000        144.063         35.938    80.04


PROMPT *** Creating Index on 'T_TRANS_MEMO' table ***

----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_MEMO#TUID_DTS_PIDX.T_INDX_TRANS_MEMO200309
OCCUPIED_BYTES  :          8,192
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_MEMO#TUID_DTS_PIDX.T_INDX_TRANS_MEMO200310
OCCUPIED_BYTES  :          8,192
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_MEMO#TUID_DTS_PIDX.T_INDX_TRANS_MEMO200311
OCCUPIED_BYTES  :          8,192
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_MEMO#TUID_DTS_PIDX.T_INDX_TRANS_MEMO200312
OCCUPIED_BYTES  :          8,192
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_MEMO#TUID_DTS_PIDX.T_INDX_TRANS_MEMO200401
OCCUPIED_BYTES  :          8,192
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_MEMO#TUID_DTS_PIDX.T_INDX_TRANS_MEMO200402
OCCUPIED_BYTES  :          8,192
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_MEMO#TUID_DTS_PIDX.T_INDX_TRANS_MEMO200403
OCCUPIED_BYTES  :          8,192
----------------------------------------------------------------

CREATE INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
ON cvm_admin.t_trans_memo(datestamp, tuid)
PCTFREE  5
INITRANS 2
MAXTRANS 255
STORAGE
(
  INITIAL     64K
  NEXT        128K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  UNLIMITED
  FREELISTS   2
)
LOCAL
(
  PARTITION t_indx_trans_memo200309
    TABLESPACE cvm_200309_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200310
    TABLESPACE cvm_200310_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200311
    TABLESPACE cvm_200311_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200312
    TABLESPACE cvm_200312_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200401
    TABLESPACE cvm_200401_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      PCTINCREASE 0
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200402
    TABLESPACE cvm_200402_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      PCTINCREASE 0
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200403
    TABLESPACE cvm_200403_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      PCTINCREASE 0
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      FREELISTS   1
    )
)
/
Index created.

SELECT partition_name,
       tablespace_name,
       ini_trans, 
       max_trans, 
       initial_extent, 
       next_extent, 
       min_extent, 
       max_extent, 
       pct_increase, 
       freelists, 
       freelist_groups, 
       pct_free, 
       logging 
  FROM dba_ind_partitions 
 WHERE index_owner = 'CVM_ADMIN' 
   AND index_name  = 'T_TRANS_MEMO#DTS_TUID_PIDX'
 ORDER BY 1
/   

PARTITION_NAME                 TABLESPACE_NAME                   INI_TRANS    MAX_TRANS INITIAL_EXTENT  NEXT_EXTENT   MIN_EXTENT   MAX_EXTENT PCT_INCREASE    FREELISTS FREELIST_GROUPS     PCT_FREE LOGGING
------------------------------ ------------------------------ ------------ ------------ -------------- ------------ ------------ ------------ ------------ ------------ --------------- ------------ -------
T_INDX_TRANS_MEMO200309        CVM_200309_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 YES
T_INDX_TRANS_MEMO200310        CVM_200310_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 YES
T_INDX_TRANS_MEMO200311        CVM_200311_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 YES
T_INDX_TRANS_MEMO200312        CVM_200312_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200401        CVM_200401_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200402        CVM_200402_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 YES
T_INDX_TRANS_MEMO200403        CVM_200403_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 NO



DROP INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
/
Index dropped.




**********************************************************
Add NOLOGGING statement
**********************************************************

CREATE INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
ON cvm_admin.t_trans_memo(datestamp, tuid)
PCTFREE  5
INITRANS 2
MAXTRANS 255
NOLOGGING
PARALLEL 2
STORAGE
(
  INITIAL     64K
  NEXT        128K
  MINEXTENTS  1
  MAXEXTENTS  UNLIMITED
  PCTINCREASE 0
  FREELISTS   2
)
LOCAL
(
  PARTITION t_indx_trans_memo200309
    TABLESPACE cvm_200309_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200310
    TABLESPACE cvm_200310_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200311
    TABLESPACE cvm_200311_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200312
    TABLESPACE cvm_200312_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200401
    TABLESPACE cvm_200401_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200402
    TABLESPACE cvm_200402_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200403
    TABLESPACE cvm_200403_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    )
)
/
Index created.

PARTITION_NAME                 TABLESPACE_NAME                   INI_TRANS    MAX_TRANS INITIAL_EXTENT  NEXT_EXTENT   MIN_EXTENT   MAX_EXTENT PCT_INCREASE    FREELISTS FREELIST_GROUPS     PCT_FREE LOGGING
------------------------------ ------------------------------ ------------ ------------ -------------- ------------ ------------ ------------ ------------ ------------ --------------- ------------ -------
T_INDX_TRANS_MEMO200309        CVM_200309_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200310        CVM_200310_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200311        CVM_200311_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200312        CVM_200312_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200401        CVM_200401_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200402        CVM_200402_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 NO
T_INDX_TRANS_MEMO200403        CVM_200403_INDX                           2          255          16384        65536            1   2147483645            0            1               1            5 NO

SELECT leaf_blocks,
       distinct_keys, 
       avg_leaf_blocks_per_key, 
       avg_data_blocks_per_key, 
       clustering_factor, 
       num_rows, 
       last_analyzed, 
       buffer_pool, 
       user_stats, 
       global_stats 
  FROM dba_ind_partitions 
 WHERE index_owner = 'CVM_ADMIN' 
   AND index_name  = 'T_TRANS_MEMO#DTS_TUID_PIDX'
/   

 LEAF_BLOCKS DISTINCT_KEYS AVG_LEAF_BLOCKS_PER_KEY AVG_DATA_BLOCKS_PER_KEY CLUSTERING_FACTOR     NUM_ROWS LAST_ANAL BUFFER_ USE GLO
------------ ------------- ----------------------- ----------------------- ----------------- ------------ --------- ------- --- ---
                                                                                                            DEFAULT NO  NO
                                                                                                            DEFAULT NO  NO
                                                                                                            DEFAULT NO  NO
                                                                                                            DEFAULT NO  NO
                                                                                                            DEFAULT NO  NO
                                                                                                            DEFAULT NO  NO
                                                                                                            DEFAULT NO  NO
ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
  REBUILD PARTITION t_indx_trans_memo200309
/
ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
  REBUILD PARTITION t_indx_trans_memo200310
/
ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
  REBUILD PARTITION t_indx_trans_memo200311
/
ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
  REBUILD PARTITION t_indx_trans_memo200312
/
ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
  REBUILD PARTITION t_indx_trans_memo200401
/
ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
  REBUILD PARTITION t_indx_trans_memo200402
/
ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
  REBUILD PARTITION t_indx_trans_memo200403
/

****************************************************
STATISTICS
****************************************************

ANALYZE INDEX CVM_ADMIN.T_TRANS_MEMO#DTS_TUID_PIDX
COMPUTE STATISTICS;

 LEAF_BLOCKS DISTINCT_KEYS AVG_LEAF_BLOCKS_PER_KEY AVG_DATA_BLOCKS_PER_KEY CLUSTERING_FACTOR     NUM_ROWS LAST_ANAL BUFFER_ USE GLO
------------ ------------- ----------------------- ----------------------- ----------------- ------------ --------- ------- --- ---
           0             0                       0                       0                 0            0 30-MAR-04 DEFAULT NO  NO
           0             0                       0                       0                 0            0 30-MAR-04 DEFAULT NO  NO
           0             0                       0                       0                 0            0 30-MAR-04 DEFAULT NO  NO
           0             0                       0                       0                 0            0 30-MAR-04 DEFAULT NO  NO
           0             0                       0                       0                 0            0 30-MAR-04 DEFAULT NO  NO
           0             0                       0                       0                 0            0 30-MAR-04 DEFAULT NO  NO
           0             0                       0                       0                 0            0 30-MAR-04 DEFAULT NO  NO



SET TIMING ON

============================================
T_TRANS_MEMO
============================================
ANALYZE TABLE cvm_admin.t_trans_memo
PARTITION (t_trans_memo200309)
COMPUTE STATISTICS
/
ANALYZE TABLE cvm_admin.t_trans_memo
PARTITION (t_trans_memo200310)
COMPUTE STATISTICS
/
ANALYZE TABLE cvm_admin.t_trans_memo
PARTITION (t_trans_memo200311)
COMPUTE STATISTICS
/
ANALYZE TABLE cvm_admin.t_trans_memo
PARTITION (t_trans_memo200312)
COMPUTE STATISTICS
/
ANALYZE TABLE cvm_admin.t_trans_memo
PARTITION (t_trans_memo200401)
COMPUTE STATISTICS
/
ANALYZE TABLE cvm_admin.t_trans_memo
PARTITION (t_trans_memo200402)
COMPUTE STATISTICS
/
ANALYZE TABLE cvm_admin.t_trans_memo
PARTITION (t_trans_memo200403)
COMPUTE STATISTICS
/

============================================
T_TRANS_PAYMENT_KEY
============================================
ANALYZE TABLE cvm_admin.t_trans_payment_key
PARTITION (t_trans_paykey200309)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:02:132.51

ANALYZE TABLE cvm_admin.t_trans_payment_key
PARTITION (t_trans_paykey200310)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:02:165.27

ANALYZE TABLE cvm_admin.t_trans_payment_key
PARTITION (t_trans_paykey200311)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:03:189.63

ANALYZE TABLE cvm_admin.t_trans_payment_key
PARTITION (t_trans_paykey200312)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:05:320.31

ANALYZE TABLE cvm_admin.t_trans_payment_key
PARTITION (t_trans_paykey200401)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:03:192.37

ANALYZE TABLE cvm_admin.t_trans_payment_key
PARTITION (t_trans_paykey200402)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:03:189.32

ANALYZE TABLE cvm_admin.t_trans_payment_key
PARTITION (t_trans_paykey200403)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:02:151.08


============================================
T_SIGNATURE
============================================
ANALYZE TABLE cvm_admin.t_signature
PARTITION (t_sig200309)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:01:66.36

ANALYZE TABLE cvm_admin.t_signature
PARTITION (t_sig200310)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:01:84.71

ANALYZE TABLE cvm_admin.t_signature
PARTITION (t_sig200311)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:01:73.97

ANALYZE TABLE cvm_admin.t_signature
PARTITION (t_sig200312)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:02:124.69

ANALYZE TABLE cvm_admin.t_signature
PARTITION (t_sig200401)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:01:96.28

ANALYZE TABLE cvm_admin.t_signature
PARTITION (t_sig200402)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:01:74.17

ANALYZE TABLE cvm_admin.t_signature
PARTITION (t_sig200403)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:01:74.98

============================================
T_TRANSACTION
============================================

ANALYZE TABLE cvm_admin.t_transaction
PARTITION (t_trans200309)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:01:87.95

ANALYZE TABLE cvm_admin.t_transaction
PARTITION (t_trans200310)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:01:95.97

ANALYZE TABLE cvm_admin.t_transaction
PARTITION (t_trans200311)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:03:206.57

ANALYZE TABLE cvm_admin.t_transaction
PARTITION (t_trans200312)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:04:249.29

ANALYZE TABLE cvm_admin.t_transaction
PARTITION (t_trans200401)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:02:126.93

ANALYZE TABLE cvm_admin.t_transaction
PARTITION (t_trans200402)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:01:90.10

ANALYZE TABLE cvm_admin.t_transaction
PARTITION (t_trans200403)
COMPUTE STATISTICS
/
Table analyzed.
Elapsed: 00:02:137.57

============================================
T_TRANSACTION_KEY
============================================

ANALYZE TABLE cvm_admin.t_transaction_key
PARTITION (t_trans_key200309)
COMPUTE STATISTICS
/
Elapsed: 00:05:305.89

ANALYZE TABLE cvm_admin.t_transaction_key
PARTITION (t_trans_key200310)
COMPUTE STATISTICS
/
Elapsed: 00:04:280.74

ANALYZE TABLE cvm_admin.t_transaction_key
PARTITION (t_trans_key200311)
COMPUTE STATISTICS
/
Elapsed: 00:05:323.45

ANALYZE TABLE cvm_admin.t_transaction_key
PARTITION (t_trans_key200312)
COMPUTE STATISTICS
/
Elapsed: 00:09:589.77

ANALYZE TABLE cvm_admin.t_transaction_key
PARTITION (t_trans_key200401)
COMPUTE STATISTICS
/
Elapsed: 00:05:324.88

ANALYZE TABLE cvm_admin.t_transaction_key
PARTITION (t_trans_key200402)
COMPUTE STATISTICS
/
Elapsed: 00:05:321.41

ANALYZE TABLE cvm_admin.t_transaction_key
PARTITION (t_trans_key200403)
COMPUTE STATISTICS
/
Elapsed: 00:04:265.92

SET TIMING OFF


*********************************************************************
RECREATE INDEXES
*********************************************************************

DROP INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
/
DROP INDEX cvm_admin.t_sign#sig_id_dts_pidx 
/
DROP INDEX cvm_admin.t_sign#tuid_sig_id_dts_puidx
/
DROP INDEX cvm_admin.t_transaction#tuid_dts_puidx
/
DROP INDEX cvm_admin.t_trans_key#tuid_dts_pidx 
/
DROP INDEX cvm_admin.t_trans_key#tuid_dts_pidx
                     *
ERROR at line 1:
ORA-02429: cannot drop index used for enforcement of unique/primary key

DROP INDEX cvm_admin.t_trans_key#prp_acct_dts_puidx
/
DROP INDEX cvm_admin.t_trans_key#acct_dts_pidx
/
DROP INDEX cvm_admin.t_trans_pay_key#pcard_dts_pidx
/
DROP INDEX cvm_admin.t_trans_pay_key#tuid_dts_pidx
/

******************************

ALTER TABLE cvm_admin.t_trans_memo
  DISABLE CONSTRAINT t_trans_memo#tuid_dts_fk
/
Table altered.

ALTER TABLE cvm_admin.t_transaction
  DISABLE CONSTRAINT t_transaction#tuid_dts_fk
/
Table altered.

ALTER TABLE cvm_admin.t_signature
  DISABLE CONSTRAINT t_signature#tuid_dts_fk
/
Table altered.

ALTER TABLE cvm_admin.t_trans_payment_key
  DISABLE CONSTRAINT t_trans_pay_key#tuid_dts_fk
/
Table altered.

ALTER TABLE cvm_admin.t_transaction_key
  DISABLE CONSTRAINT t_trans_key#tuid_dts_pk
/
Table altered.

DROP INDEX cvm_admin.t_trans_key#tuid_dts_pidx
/
Index dropped.


Tablespace Name  File Name                                                        Total (Mb)      Used (Mb)      Free (Mb) Pct Used
---------------- ------------------------------------------------------------ -------------- -------------- -------------- --------
CVM_200309_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200309_indx.dbf                  100.000           .000        100.000
CVM_200310_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200310_indx.dbf                  150.000           .000        150.000
CVM_200311_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200311_indx.dbf                  150.000           .000        150.000
CVM_200312_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200312_indx.dbf                  170.000           .000        170.000
CVM_200401_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200401_indx.dbf                  300.000           .000        300.000
CVM_200402_INDX  /dbbig/oracle/oradata/cvtest/cvm/cvm_200402_indx.dbf                300.000           .000        300.000
CVM_200403_INDX  /db2/oracle/oradata/cvtest/cvm/cvm_200403_indx.dbf                  180.000           .000        180.000


DROP TABLESPACE cvm_200402_indx
/
Tablespace dropped.

CREATE TABLESPACE cvm_200402_indx
DATAFILE '/db2/oracle/oradata/cvtest/cvm/cvm_200402_indx.dbf' SIZE 200M REUSE
AUTOEXTEND OFF
DEFAULT STORAGE
( 
  INITIAL     32K 
  NEXT        32K 
  MINEXTENTS  1
  MAXEXTENTS  1024
  PCTINCREASE 0
)
NOLOGGING
ONLINE 
PERMANENT
/
Tablespace created.

CREATE INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
ON cvm_admin.t_trans_memo(datestamp, tuid)
PCTFREE  5
INITRANS 2
MAXTRANS 255
NOLOGGING
PARALLEL 2
STORAGE
(
  INITIAL     64K
  NEXT        128K
  MINEXTENTS  1
  MAXEXTENTS  UNLIMITED
  PCTINCREASE 0
  FREELISTS   2
)
LOCAL
(
  PARTITION t_indx_trans_memo200309
    TABLESPACE cvm_200309_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200310
    TABLESPACE cvm_200310_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200311
    TABLESPACE cvm_200311_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200312
    TABLESPACE cvm_200312_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200401
    TABLESPACE cvm_200401_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200402
    TABLESPACE cvm_200402_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_memo200403
    TABLESPACE cvm_200403_indx
    STORAGE
    (
      INITIAL     16K
      NEXT        64K
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    )
)
/
Index created.


--ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_memo200309
--/
--ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_memo200310
--/
--ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_memo200311
--/
--ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_memo200312
--/
--ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_memo200401
--/
--ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_memo200402
--/
--ALTER INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_memo200403
--/

ANALYZE INDEX cvm_admin.t_trans_memo#dts_tuid_pidx
COMPUTE STATISTICS
/
Index analyzed.


PROMPT *** Creating Unique Index on 'T_SIGNATURE' table ***

----------------------------------------------------------------
OBJECT_NAME     : T_SIGN#TUID_SIG_ID_DTS_PUIDX.T_INDX_SIGTUID200309
OCCUPIED_BYTES  :      8,089,600
----------------------------------------------------------------
OBJECT_NAME     : T_SIGN#TUID_SIG_ID_DTS_PUIDX.T_INDX_SIGTUID200310
OCCUPIED_BYTES  :      9,854,976
----------------------------------------------------------------
OBJECT_NAME     : T_SIGN#TUID_SIG_ID_DTS_PUIDX.T_INDX_SIGTUID200311
OCCUPIED_BYTES  :     11,137,024
----------------------------------------------------------------
OBJECT_NAME     : T_SIGN#TUID_SIG_ID_DTS_PUIDX.T_INDX_SIGTUID200312
OCCUPIED_BYTES  :     18,145,280
----------------------------------------------------------------
OBJECT_NAME     : T_SIGN#TUID_SIG_ID_DTS_PUIDX.T_INDX_SIGTUID200401
OCCUPIED_BYTES  :     11,268,096
----------------------------------------------------------------
OBJECT_NAME     : T_SIGN#TUID_SIG_ID_DTS_PUIDX.T_INDX_SIGTUID200402
OCCUPIED_BYTES  :     17,948,672
----------------------------------------------------------------
OBJECT_NAME     : T_SIGN#TUID_SIG_ID_DTS_PUIDX.T_INDX_SIGTUID200403
OCCUPIED_BYTES  :      7,905,280
----------------------------------------------------------------

CREATE UNIQUE INDEX cvm_admin.t_sign#dts_tuid_sigid_puidx
ON cvm_admin.t_signature(datestamp, tuid, sig_id)
PCTFREE  5
INITRANS 2
MAXTRANS 255
NOLOGGING
PARALLEL 2
STORAGE
(
  INITIAL     16M
  NEXT        8M
  MINEXTENTS  1
  MAXEXTENTS  UNLIMITED
  PCTINCREASE 0
  FREELISTS   2
)
LOCAL
( 
  PARTITION t_indx_sigtuid200309
    TABLESPACE cvm_200309_indx
    STORAGE
    (
      INITIAL     9M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_sigtuid200310
    TABLESPACE cvm_200310_indx
    STORAGE
    (
      INITIAL     10M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_sigtuid200311
    TABLESPACE cvm_200311_indx
    STORAGE
    (
      INITIAL     12M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_sigtuid200312
    TABLESPACE cvm_200312_indx
    STORAGE
    (
      INITIAL     19M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_sigtuid200401
    TABLESPACE cvm_200401_indx
    STORAGE
    (
      INITIAL     12M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_sigtuid200402
    TABLESPACE cvm_200402_indx
    STORAGE
    (
      INITIAL     18M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_sigtuid200403
    TABLESPACE cvm_200403_indx
    STORAGE
    (
      INITIAL     9M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    )
)
/

--ALTER INDEX cvm_admin.t_sign#dts_tuid_sigid_puidx
--  REBUILD PARTITION t_indx_sigtuid200309
--/
--ALTER INDEX cvm_admin.t_sign#dts_tuid_sigid_puidx
--  REBUILD PARTITION t_indx_sigtuid200310
--/
--ALTER INDEX cvm_admin.t_sign#dts_tuid_sigid_puidx
--  REBUILD PARTITION t_indx_sigtuid200311
--/
--ALTER INDEX cvm_admin.t_sign#dts_tuid_sigid_puidx
--  REBUILD PARTITION t_indx_sigtuid200312
--/
--ALTER INDEX cvm_admin.t_sign#dts_tuid_sigid_puidx
--  REBUILD PARTITION t_indx_sigtuid200401
--/
--ALTER INDEX cvm_admin.t_sign#dts_tuid_sigid_puidx
--  REBUILD PARTITION t_indx_sigtuid200402
--/
--ALTER INDEX cvm_admin.t_sign#dts_tuid_sigid_puidx
--  REBUILD PARTITION t_indx_sigtuid200403
--/

ANALYZE INDEX cvm_admin.t_sign#dts_tuid_sigid_puidx
COMPUTE STATISTICS
/
Index analyzed.

PROMPT *** Creating Unique Index on 'T_TRANSACTION' table ***

----------------------------------------------------------------
OBJECT_NAME     : T_TRANSACTION#TUID_DTS_PUIDX.T_INDX_TRANS200309
OCCUPIED_BYTES  :      7,163,904
----------------------------------------------------------------
OBJECT_NAME     : T_TRANSACTION#TUID_DTS_PUIDX.T_INDX_TRANS200310
OCCUPIED_BYTES  :      8,749,056
----------------------------------------------------------------
OBJECT_NAME     : T_TRANSACTION#TUID_DTS_PUIDX.T_INDX_TRANS200311
OCCUPIED_BYTES  :      9,981,952
----------------------------------------------------------------
OBJECT_NAME     : T_TRANSACTION#TUID_DTS_PUIDX.T_INDX_TRANS200312
OCCUPIED_BYTES  :     16,101,376
----------------------------------------------------------------
OBJECT_NAME     : T_TRANSACTION#TUID_DTS_PUIDX.T_INDX_TRANS200401
OCCUPIED_BYTES  :      9,981,952
----------------------------------------------------------------
OBJECT_NAME     : T_TRANSACTION#TUID_DTS_PUIDX.T_INDX_TRANS200402
OCCUPIED_BYTES  :     15,953,920
----------------------------------------------------------------
OBJECT_NAME     : T_TRANSACTION#TUID_DTS_PUIDX.T_INDX_TRANS200403
OCCUPIED_BYTES  :      7,041,024
----------------------------------------------------------------

CREATE UNIQUE INDEX cvm_admin.t_transaction#dts_tuid_puidx
ON cvm_admin.t_transaction(datestamp, tuid)
PCTFREE  5
INITRANS 2
MAXTRANS 255
NOLOGGING
PARALLEL 2
STORAGE
(
  INITIAL     16M
  NEXT        8M
  MINEXTENTS  1
  MAXEXTENTS  UNLIMITED
  PCTINCREASE 0
  FREELISTS   2
)
LOCAL
(
  PARTITION t_indx_trans200309
    TABLESPACE cvm_200309_indx
    STORAGE
    (
      INITIAL     8M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans200310
    TABLESPACE cvm_200310_indx
    STORAGE
    (
      INITIAL     9M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans200311
    TABLESPACE cvm_200311_indx
    STORAGE
    (
      INITIAL     10M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans200312
    TABLESPACE cvm_200312_indx
    STORAGE
    (
      INITIAL     17M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans200401
    TABLESPACE cvm_200401_indx
    STORAGE
    (
      INITIAL     10M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans200402
    TABLESPACE cvm_200402_indx
    STORAGE
    (
      INITIAL     16M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans200403
    TABLESPACE cvm_200403_indx
    STORAGE
    (
      INITIAL     8M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    )
)
/

--ALTER INDEX cvm_admin.t_transaction#dts_tuid_puidx
--  REBUILD PARTITION t_indx_trans200309
--/
--ALTER INDEX cvm_admin.t_transaction#dts_tuid_puidx
--  REBUILD PARTITION t_indx_trans200310
--/
--ALTER INDEX cvm_admin.t_transaction#dts_tuid_puidx
--  REBUILD PARTITION t_indx_trans200311
--/
--ALTER INDEX cvm_admin.t_transaction#dts_tuid_puidx
--  REBUILD PARTITION t_indx_trans200312
--/
--ALTER INDEX cvm_admin.t_transaction#dts_tuid_puidx
--  REBUILD PARTITION t_indx_trans200401
--/
--ALTER INDEX cvm_admin.t_transaction#dts_tuid_puidx
--  REBUILD PARTITION t_indx_trans200402
--/
--ALTER INDEX cvm_admin.t_transaction#dts_tuid_puidx
  REBUILD PARTITION t_indx_trans200403
--/

ANALYZE INDEX cvm_admin.t_transaction#dts_tuid_puidx
COMPUTE STATISTICS
/
Index analyzed.

PROMPT *** Creating Index on 'T_TRANSACTION_KEY' table ***

----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#TUID_DTS_PIDX.T_INDX_TRANSKEY200309
OCCUPIED_BYTES  :      7,499,776
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#TUID_DTS_PIDX.T_INDX_TRANSKEY200310
OCCUPIED_BYTES  :      9,162,752
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#TUID_DTS_PIDX.T_INDX_TRANSKEY200311
OCCUPIED_BYTES  :     10,457,088
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#TUID_DTS_PIDX.T_INDX_TRANSKEY200312
OCCUPIED_BYTES  :     16,867,328
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#TUID_DTS_PIDX.T_INDX_TRANSKEY200401
OCCUPIED_BYTES  :     10,457,088
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#TUID_DTS_PIDX.T_INDX_TRANSKEY200402
OCCUPIED_BYTES  :     15,691,776
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#TUID_DTS_PIDX.T_INDX_TRANSKEY200403
OCCUPIED_BYTES  :      8,101,888
----------------------------------------------------------------

CREATE INDEX cvm_admin.t_trans_key#dts_tuid_pidx 
ON cvm_admin.t_transaction_key(datestamp, tuid)
PCTFREE  5
INITRANS 2
MAXTRANS 255
NOLOGGING
PARALLEL 2
STORAGE
(
  INITIAL     16M
  NEXT        8M
  MINEXTENTS  1
  MAXEXTENTS  UNLIMITED
  PCTINCREASE 0
  FREELISTS   2
)
LOCAL
(
  PARTITION t_indx_transkey200309
    TABLESPACE cvm_200309_indx
    STORAGE
    (
      INITIAL     8M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey200310
    TABLESPACE cvm_200310_indx
    STORAGE
    (
      INITIAL     10M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey200311
    TABLESPACE cvm_200311_indx
    STORAGE
    (
      INITIAL     11M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey200312
    TABLESPACE cvm_200312_indx
    STORAGE
    (
      INITIAL     17M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey200401
    TABLESPACE cvm_200401_indx
    STORAGE
    (
      INITIAL     11M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey200402
    TABLESPACE cvm_200402_indx
    STORAGE
    (
      INITIAL     16M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey200403
    TABLESPACE cvm_200403_indx
    STORAGE
    (
      INITIAL     9M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    )
)
/
Index created.
Elapsed: 00:14:36.29

--ALTER INDEX cvm_admin.t_trans_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_transkey200309
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_transkey200310
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_transkey200311
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_transkey200312
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_transkey200401
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_transkey200402
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_transkey200403
--/

ANALYZE INDEX cvm_admin.t_trans_key#dts_tuid_pidx
COMPUTE STATISTICS
/
Index analyzed.
Elapsed: 00:00:06.06

PROMPT *** Creating Unique Index on 'T_TRANSACTION_KEY' table ***

----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#PRP_ACCT_DTS_PUIDX.T_INDX_TRANSKEY_UN200309
OCCUPIED_BYTES  :     20,062,208
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#PRP_ACCT_DTS_PUIDX.T_INDX_TRANSKEY_UN200310
OCCUPIED_BYTES  :     24,391,680
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#PRP_ACCT_DTS_PUIDX.T_INDX_TRANSKEY_UN200311
OCCUPIED_BYTES  :     27,844,608
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#PRP_ACCT_DTS_PUIDX.T_INDX_TRANSKEY_UN200312
OCCUPIED_BYTES  :     44,990,464
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#PRP_ACCT_DTS_PUIDX.T_INDX_TRANSKEY_UN200401
OCCUPIED_BYTES  :     27,906,048
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#PRP_ACCT_DTS_PUIDX.T_INDX_TRANSKEY_UN200402
OCCUPIED_BYTES  :     46,632,960
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_KEY#PRP_ACCT_DTS_PUIDX.T_INDX_TRANSKEY_UN200403
OCCUPIED_BYTES  :     35,414,016
----------------------------------------------------------------

CREATE UNIQUE INDEX cvm_admin.t_trans_key#dts_acct_prp_puidx
ON cvm_admin.t_transaction_key(datestamp, account_id, prop_trans_id)
PCTFREE  5
INITRANS 2
MAXTRANS 255
NOLOGGING
PARALLEL 2
STORAGE
(
  INITIAL     32M
  NEXT        16M
  MINEXTENTS  1
  MAXEXTENTS  UNLIMITED
  PCTINCREASE 0
  FREELISTS   2
)
LOCAL
(
  PARTITION t_indx_transkey_un200309
    TABLESPACE cvm_200309_indx
    STORAGE
    (
      INITIAL     21M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey_un200310
    TABLESPACE cvm_200310_indx
    STORAGE
    (
      INITIAL     25M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey_un200311
    TABLESPACE cvm_200311_indx
    STORAGE
    (
      INITIAL     28M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey_un200312
    TABLESPACE cvm_200312_indx
    STORAGE
    (
      INITIAL     45M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey_un200401
    TABLESPACE cvm_200401_indx
    STORAGE
    (
      INITIAL     28M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey_un200402
    TABLESPACE cvm_200402_indx
    STORAGE
    (
      INITIAL     47M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_transkey_un200403
    TABLESPACE cvm_200403_indx
    STORAGE
    (
      INITIAL     36M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    )
)
/



--ALTER INDEX cvm_admin.t_trans_key#dts_acct_prp_puidx
--  REBUILD PARTITION t_indx_transkey_un200309
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_acct_prp_puidx
--  REBUILD PARTITION t_indx_transkey_un200310
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_acct_prp_puidx
--  REBUILD PARTITION t_indx_transkey_un200311
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_acct_prp_puidx
--  REBUILD PARTITION t_indx_transkey_un200312
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_acct_prp_puidx
--  REBUILD PARTITION t_indx_transkey_un200401
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_acct_prp_puidx
--  REBUILD PARTITION t_indx_transkey_un200402
--/
--ALTER INDEX cvm_admin.t_trans_key#dts_acct_prp_puidx
--  REBUILD PARTITION t_indx_transkey_un200403
--/

ANALYZE INDEX cvm_admin.t_trans_key#dts_acct_prp_puidx
COMPUTE STATISTICS
/
Index analyzed.

PROMPT *** Creating Index on 'T_TRANS_PAYMENT_KEY' table ***

----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#PCARD_DTS_PIDX.T_INDX_TRANS_PKEYCRD200309
OCCUPIED_BYTES  :     10,907,648
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#PCARD_DTS_PIDX.T_INDX_TRANS_PKEYCRD200310
OCCUPIED_BYTES  :     13,352,960
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#PCARD_DTS_PIDX.T_INDX_TRANS_PKEYCRD200311
OCCUPIED_BYTES  :     15,228,928
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#PCARD_DTS_PIDX.T_INDX_TRANS_PKEYCRD200312
OCCUPIED_BYTES  :     24,776,704
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#PCARD_DTS_PIDX.T_INDX_TRANS_PKEYCRD200401
OCCUPIED_BYTES  :     15,454,208
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#PCARD_DTS_PIDX.T_INDX_TRANS_PKEYCRD200402
OCCUPIED_BYTES  :     17,539,072
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#PCARD_DTS_PIDX.T_INDX_TRANS_PKEYCRD200403
OCCUPIED_BYTES  :     15,302,656
----------------------------------------------------------------

CREATE INDEX cvm_admin.t_trans_pay_key#dts_pcard_pidx
ON cvm_admin.t_trans_payment_key(datestamp, primary_card_no)
PCTFREE  5
INITRANS 2
MAXTRANS 255
NOLOGGING
PARALLEL 2
STORAGE
(
  INITIAL     16M
  NEXT        16M
  MINEXTENTS  1
  MAXEXTENTS  UNLIMITED
  PCTINCREASE 0
  FREELISTS   2
)
LOCAL
(
  PARTITION t_indx_trans_pkeycrd200309
    TABLESPACE cvm_200309_indx
    STORAGE
    (
      INITIAL     11M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_pkeycrd200310
    TABLESPACE cvm_200310_indx
    STORAGE
    (
      INITIAL     14M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_pkeycrd200311
    TABLESPACE cvm_200311_indx
    STORAGE
    (
      INITIAL     16M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_pkeycrd200312
    TABLESPACE cvm_200312_indx
    STORAGE
    (
      INITIAL     25M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_pkeycrd200401
    TABLESPACE cvm_200401_indx
    STORAGE
    (
      INITIAL     16M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_pkeycrd200402
    TABLESPACE cvm_200402_indx
    STORAGE
    (
      INITIAL     18M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_pkeycrd200403
    TABLESPACE cvm_200403_indx
    STORAGE
    (
      INITIAL     16M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    )
)
/
Index created.
Elapsed: 00:29:47.81

--ALTER INDEX cvm_admin.t_trans_pay_key#dts_pcard_pidx
--  REBUILD PARTITION t_indx_trans_pkeycrd200309
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_pcard_pidx
--  REBUILD PARTITION t_indx_trans_pkeycrd200310
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_pcard_pidx
--  REBUILD PARTITION t_indx_trans_pkeycrd200311
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_pcard_pidx
--  REBUILD PARTITION t_indx_trans_pkeycrd200312
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_pcard_pidx
--  REBUILD PARTITION t_indx_trans_pkeycrd200401
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_pcard_pidx
--  REBUILD PARTITION t_indx_trans_pkeycrd200402
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_pcard_pidx
--  REBUILD PARTITION t_indx_trans_pkeycrd200403
--/

ANALYZE INDEX cvm_admin.t_trans_pay_key#dts_pcard_pidx
COMPUTE STATISTICS
/
Index analyzed.
Elapsed: 00:00:07.04

PROMPT *** Creating Index on 'T_TRANS_PAYMENT_KEY' table ***

----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#TUID_DTS_PIDX.T_INDX_TRANS_PAYKEY200309
OCCUPIED_BYTES  :      7,548,928
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#TUID_DTS_PIDX.T_INDX_TRANS_PAYKEY200310
OCCUPIED_BYTES  :      9,236,480
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#TUID_DTS_PIDX.T_INDX_TRANS_PAYKEY200311
OCCUPIED_BYTES  :     10,534,912
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#TUID_DTS_PIDX.T_INDX_TRANS_PAYKEY200312
OCCUPIED_BYTES  :     17,076,224
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#TUID_DTS_PIDX.T_INDX_TRANS_PAYKEY200401
OCCUPIED_BYTES  :     10,625,024
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#TUID_DTS_PIDX.T_INDX_TRANS_PAYKEY200402
OCCUPIED_BYTES  :     14,278,656
----------------------------------------------------------------
OBJECT_NAME     : T_TRANS_PAY_KEY#TUID_DTS_PIDX.T_INDX_TRANS_PAYKEY200403
OCCUPIED_BYTES  :      8,134,656
----------------------------------------------------------------

CREATE INDEX cvm_admin.t_trans_pay_key#dts_tuid_pidx
ON cvm_admin.t_trans_payment_key(datestamp, tuid)
PCTFREE  5
INITRANS 2
MAXTRANS 255
NOLOGGING
PARALLEL 2
STORAGE
(
  INITIAL     16M
  NEXT        8M
  MINEXTENTS  1
  MAXEXTENTS  UNLIMITED
  PCTINCREASE 0
  FREELISTS   2
)
LOCAL
(
  PARTITION t_indx_trans_paykey200309
    TABLESPACE cvm_200309_indx
    STORAGE
    (
      INITIAL     8M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_paykey200310
    TABLESPACE cvm_200310_indx
    STORAGE
    (
      INITIAL     10M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_paykey200311
    TABLESPACE cvm_200311_indx
    STORAGE
    (
      INITIAL     11M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_paykey200312
    TABLESPACE cvm_200312_indx
    STORAGE
    (
      INITIAL     18M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_paykey200401
    TABLESPACE cvm_200401_indx
    STORAGE
    (
      INITIAL     11M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_paykey200402
    TABLESPACE cvm_200402_indx
    STORAGE
    (
      INITIAL     15M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    ),
  PARTITION t_indx_trans_paykey200403
    TABLESPACE cvm_200403_indx
    STORAGE
    (
      INITIAL     9M
      NEXT        1M
      MINEXTENTS  1
      MAXEXTENTS  UNLIMITED
      PCTINCREASE 0
      FREELISTS   1
    )
)
/
Index created.
Elapsed: 00:18:39.69

--ALTER INDEX cvm_admin.t_trans_pay_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_paykey200309
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_paykey200310
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_paykey200311
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_paykey200312
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_paykey200401
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_paykey200402
--/
--ALTER INDEX cvm_admin.t_trans_pay_key#dts_tuid_pidx
--  REBUILD PARTITION t_indx_trans_paykey200403
--/

ANALYZE INDEX cvm_admin.t_trans_pay_key#dts_tuid_pidx
COMPUTE STATISTICS
/
Index analyzed.
Elapsed: 00:00:05.51



ALTER TABLE cvm_admin.t_transaction_key
  PARALLEL 4
  ENABLE NOVALIDATE CONSTRAINT t_trans_key#tuid_dts_pk
/
Table altered.
Elapsed: 00:00:00.12

ALTER TABLE cvm_admin.t_trans_memo
  PARALLEL 4
  ENABLE NOVALIDATE CONSTRAINT t_trans_memo#tuid_dts_fk
/
Table altered.
Elapsed: 00:00:00.06

ALTER TABLE cvm_admin.t_trans_payment_key
  PARALLEL 4
  ENABLE NOVALIDATE CONSTRAINT t_trans_pay_key#tuid_dts_fk
/
Table altered.
Elapsed: 00:00:00.02

ALTER TABLE cvm_admin.t_transaction
  PARALLEL 4
  ENABLE NOVALIDATE CONSTRAINT t_transaction#tuid_dts_fk
/
Table altered.
Elapsed: 00:00:00.05

ALTER TABLE cvm_admin.t_signature
  PARALLEL 4
  ENABLE NOVALIDATE CONSTRAINT t_signature#tuid_dts_fk
/
Table altered.
Elapsed: 00:00:00.04

PROMPT *** Creating PK Constraint on 'T_TRANSACTION_KEY' table ***
ALTER TABLE cvm_admin.t_transaction_key
ADD CONSTRAINT t_trans_key#tuid_dts_pk
  PRIMARY KEY (datestamp, tuid)
  USING INDEX 
  LOCAL
/
