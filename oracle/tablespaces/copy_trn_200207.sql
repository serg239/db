SPOOL trn200207.lst

SELECT 'TRN_200207_TRANS_PAYMENT_KEY' AS "TRN_200207 Table Name",
       COUNT(*)              AS "Rows"
  FROM cvm_admin.trn_200207_trans_payment_key@cvtest
UNION ALL
SELECT 'TRN_200207_SIGNATURE',
       COUNT(*) 
  FROM cvm_admin.trn_200207_signature@cvtest
UNION ALL
SELECT 'TRN_200207_TRANSACTION',
       COUNT(*) 
  FROM cvm_admin.trn_200207_transaction@cvtest
UNION ALL
SELECT 'TRN_200207_TRANS_MEMO',
       COUNT(*) 
  FROM cvm_admin.trn_200207_trans_memo@cvtest
UNION ALL
SELECT 'TRN_200207_TRANSACTION_KEY',
       COUNT(*) 
  FROM cvm_admin.trn_200207_transaction_key@cvtest
/

CREATE TABLESPACE trn_200207_data
DATAFILE '/db1/oracle/oradata/cvtest/cvm/trn_200207_data.dbf' SIZE 2M REUSE
AUTOEXTEND ON
NEXT       1M
MAXSIZE    20M 
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

CREATE TABLESPACE trn_200207_indx
DATAFILE '/db1/oracle/oradata/cvtest/cvm/trn_200207_indx.dbf' SIZE 2M REUSE
AUTOEXTEND ON
NEXT       1M
MAXSIZE    20M 
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

CREATE TABLESPACE trn_200207_clob
DATAFILE '/db2/oracle/oradata/cvtest/cvm/trn_200207_clob.dbf' SIZE 80M REUSE
AUTOEXTEND ON 
NEXT       10M
MAXSIZE    200M 
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

CREATE TABLE cvm_admin.trn_200207_transaction_key
PCTFREE    5
PCTUSED    95
INITRANS   1
MAXTRANS   255
STORAGE
(
  INITIAL     256K
  NEXT        128K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  2147483645
  FREELISTS   1
)
TABLESPACE trn_200207_data
AS 
  SELECT *
    FROM cvm_admin.trn_200207_transaction_key@cvtest
/

CREATE UNIQUE INDEX cvm_admin.r_200207_trk#dts_act_prp_uidx
ON cvm_admin.trn_200207_transaction_key(datestamp, account_id, prop_trans_id)
TABLESPACE trn_200207_indx
PCTFREE    5
INITRANS   2
MAXTRANS   255
STORAGE
(
  INITIAL     148K
  NEXT        16K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  2147483645
  FREELISTS   1
)
/

CREATE INDEX cvm_admin.r_200207_trk#dts_tuid_idx
ON cvm_admin.trn_200207_transaction_key(datestamp, tuid)
TABLESPACE trn_200207_indx
PCTFREE    5
INITRANS   2
MAXTRANS   255
STORAGE
(
  INITIAL     64K
  NEXT        16K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  2147483645
  FREELISTS   3
)
/

CREATE TABLE cvm_admin.trn_200207_trans_memo
TABLESPACE trn_200207_data
PCTFREE   5
PCTUSED   95
INITRANS  1
MAXTRANS  255
STORAGE
(
  INITIAL     16K
  NEXT        16K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  2147483645
  FREELISTS   3
)
AS 
  SELECT *
    FROM cvm_admin.trn_200207_trans_memo@cvtest
/


CREATE INDEX cvm_admin.r_200207_trm#dts_tuid_idx
ON cvm_admin.trn_200207_trans_memo(datestamp, tuid)
TABLESPACE trn_200207_indx
PCTFREE   5
INITRANS  2
MAXTRANS  255
STORAGE
(
  INITIAL     16K
  NEXT        16K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  2147483645
  FREELISTS   3
)
/

CREATE TABLE cvm_admin.trn_200207_trans_payment_key
TABLESPACE trn_200207_data
PCTFREE   5
PCTUSED   95
INITRANS  1
MAXTRANS  255
STORAGE
(
  INITIAL     148K
  NEXT        16K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  2147483645
  FREELISTS   3
)
AS
  SELECT * 
    FROM cvm_admin.trn_200207_trans_payment_key@cvtest
/

CREATE INDEX cvm_admin.r_200207_trpk#dts_pcard_idx
ON cvm_admin.trn_200207_trans_payment_key(datestamp, primary_card_no)
TABLESPACE trn_200207_indx
PCTFREE   5
INITRANS  2
MAXTRANS  255
STORAGE
(
  INITIAL     132K
  NEXT        16K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  2147483645
  FREELISTS   3
)
/

CREATE INDEX cvm_admin.r_200207_trpk#dts_tuid_idx
ON cvm_admin.trn_200207_trans_payment_key(datestamp, tuid)
TABLESPACE trn_200207_indx
PCTFREE   5
INITRANS  2
MAXTRANS  255
STORAGE
(
  INITIAL     64K
  NEXT        16K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  2147483645
  FREELISTS   3
)
/

CREATE TABLE cvm_admin.trn_200207_transaction
TABLESPACE trn_200207_data
PCTFREE   5
PCTUSED   95
INITRANS  1
MAXTRANS  255
STORAGE
(
  INITIAL     16K
  NEXT        16K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  UNLIMITED
  FREELISTS   1
)
LOB(xaction_xml)
STORE AS
(
  TABLESPACE trn_200207_clob
  CHUNK      4096 
  PCTVERSION 5 
  NOCACHE 
  NOLOGGING 
  DISABLE STORAGE IN ROW 
  STORAGE
  (
    INITIAL     40M 
    NEXT        10M 
    PCTINCREASE 0 
    MAXEXTENTS  UNLIMITED
  ) 
)  
AS
  SELECT *
    FROM cvm_admin.trn_200207_transaction@cvtest
/

CREATE UNIQUE INDEX cvm_admin.r_200207_trn#dts_tuid_uidx
ON cvm_admin.trn_200207_transaction(datestamp, tuid)
TABLESPACE trn_200207_indx
PCTFREE   5
INITRANS  2
MAXTRANS  255
STORAGE
(
  INITIAL     16K
  NEXT        16K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  2147483645
  FREELISTS   3
)
/

CREATE TABLE cvm_admin.trn_200207_signature
TABLESPACE trn_200207_data
PCTFREE   5
PCTUSED   95
INITRANS  1
MAXTRANS  255
STORAGE
(
  INITIAL     16K
  NEXT        16K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  UNLIMITED
  FREELISTS   1
)
LOB(sdata)
STORE AS
(
  TABLESPACE trn_200207_clob
  CHUNK      4096 
  PCTVERSION 5 
  NOCACHE 
  NOLOGGING 
  DISABLE STORAGE IN ROW 
  STORAGE
  (
    INITIAL     20M 
    NEXT        10M 
    PCTINCREASE 0 
    MAXEXTENTS  UNLIMITED
  ) 
)
AS
  SELECT *
    FROM cvm_admin.trn_200207_signature@cvtest
/

CREATE UNIQUE INDEX cvm_admin.r_200207_sig#dts_tuid_sig_uidx
ON cvm_admin.trn_200207_signature(datestamp, tuid, sig_id)
TABLESPACE trn_200207_indx
PCTFREE   5
INITRANS  2
MAXTRANS  255
STORAGE
(
  INITIAL     16K
  NEXT        16K
  PCTINCREASE 0
  MINEXTENTS  1
  MAXEXTENTS  2147483645
  FREELISTS   3
)
/

SELECT 'TRN_200207_TRANS_PAYMENT_KEY' AS "TRN_200207 Table Name",
       COUNT(*)              AS "Rows"
  FROM cvm_admin.trn_200207_trans_payment_key
UNION ALL
SELECT 'TRN_200207_SIGNATURE',
       COUNT(*) 
  FROM cvm_admin.trn_200207_signature
UNION ALL
SELECT 'TRN_200207_TRANSACTION',
       COUNT(*) 
  FROM cvm_admin.trn_200207_transaction
UNION ALL
SELECT 'TRN_200207_TRANS_MEMO',
       COUNT(*) 
  FROM cvm_admin.trn_200207_trans_memo
UNION ALL
SELECT 'TRN_200207_TRANSACTION_KEY',
       COUNT(*) 
  FROM cvm_admin.trn_200207_transaction_key
/

@@tbsp_usage_t2.sql

ALTER TABLESPACE trn_200207_data READ ONLY
/
ALTER TABLESPACE trn_200207_indx READ ONLY
/
ALTER TABLESPACE trn_200207_clob READ ONLY
/

BEGIN
  SYS.DBMS_TTS.TRANSPORT_SET_CHECK (
  ts_list => 'TRN_200207_DATA, TRN_200207_CLOB, TRN_200207_INDX', 
  incl_constraints => TRUE); 
END;
/

SELECT * 
  FROM sys.transport_set_violations
/

SPOOL OFF
