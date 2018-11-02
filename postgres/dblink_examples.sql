/*
The dblink function executes a remote query (see contrib/dblink). It is declared to return record
since it might be used for any kind of query. The actual column set must be specified in the calling query
so that the parser knows, for example, what * should expand to.

Installation:
-------------
>psql -d db1 -U postgres < dblink.sql

CREATE FUNCTION
CREATE FUNCTION
CREATE TYPE
CREATE FUNCTION
CREATE FUNCTION
CREATE FUNCTION

Example #1:
-----------
SELECT *
  FROM dblink(’dbname=mydb’, ’SELECT proname, prosrc FROM pg_proc’)
    AS t1(proname name, prosrc text)
 WHERE proname LIKE ’bytea%’;

Example #2:
-----------
 SELECT * 
   FROM dblink('hostaddr=10.9.64.26 port=5432 dbname=db1 user=user password=pwd', ’SELECT proname, prosrc FROM pg_proc’)
    AS t1 (proname name, prosrc text)
 WHERE proname LIKE ’bytea%’;
+------------+------------+
|  proname   |   prosrc   |
+------------+------------+
| byteain    | byteain    |
| byteaout   | byteaout   |
| byteaeq    | byteaeq    |
| bytealt    | bytealt    |
| byteale    | byteale    |
| byteagt    | byteagt    |
| byteage    | byteage    |
| byteane    | byteane    |
| byteacmp   | byteacmp   |
| bytealike  | bytealike  |
| byteanlike | byteanlike |
| byteacat   | byteacat   |
| bytearecv  | bytearecv  |
| byteasend  | byteasend  |
+------------+------------+

Example #3:
-----------
INSERT INTO fdr.p20081207
SELECT *
  FROM dblink('hostaddr=10.9.64.26 
               port=5432 
               dbname=db1 
               user=user 
               password=pwd', 
              'SELECT * FROM fdr.p20081207')
   AS t1 (period_id     INTEGER, 
          device_id     INTEGER, 
          ud_class_id   INTEGER, 
          src_ip        CHARACTER(16),
          dst_ip        CHARACTER(16),
          tos           SMALLINT,
          vlan_id       SMALLINT,
          service_id    SMALLINT,
          pkts          BIGINT,
          bytes         BIGINT,
          flow_num      INTEGER,
          retrans_bytes BIGINT,
          ftype_num     SMALLINT,
          measure_1     BIGINT,
          measure_2     BIGINT,
          measure_3     BIGINT
        )
;

Example #4:
-----------
INSERT INTO fdr.p200806170001
SELECT *
  FROM dblink('hostaddr=10.9.64.22 
               port=5432
               dbname=db1
               user=user
               password=pwd', 
              'SELECT * FROM fdr.p200806170001')
   AS t1 (device_id      INTEGER,
          flow_id        INTEGER,
          src_ip         BYTEA,
          dst_ip         BYTEA,
          interface_in   SMALLINT,                 
          interface_out  SMALLINT,                 
          pkts           INTEGER,                  
          bytes          BIGINT,                   
          start_time     TIMESTAMP WITH TIME ZONE, 
          end_time       TIMESTAMP WITH TIME ZONE, 
          src_port       INTEGER,                  
          dst_port       INTEGER,                  
          flow_policy_id SMALLINT,                 
          tcp_flag_id    SMALLINT,                 
          protocol_id    SMALLINT,                 
          tos            SMALLINT,                 
          service_id     SMALLINT,                 
          priority_id    SMALLINT,                 
          retrans_bytes  INTEGER,                  
          vlan_id        SMALLINT,                 
          time_to_live   SMALLINT,                 
          ftype_num      SMALLINT,                 
          measure_1      INTEGER,                  
          measure_2      INTEGER,                  
          measure_3      INTEGER
        )
;
ERROR:  sql error
DETAIL:  out of memory for query result

Example #5:
-----------
INSERT INTO fdr.p200806170001
SELECT *
  FROM dblink('hostaddr=10.9.64.22 
               port=5432
               dbname=db1
               user=user
               password=pwd', 
              'SELECT device_id, flow_id, src_ip, dst_ip , interface_in, interface_out, 
                      pkts, bytes, start_time, end_time, src_port, dst_port, flow_policy_id,
                      tcp_flag_id, protocol_id, tos, service_id, priority_id, retrans_bytes, 
                      vlan_id, time_to_live, ftype_num, measure_1, measure_2, measure_3 
                 FROM fdr.p200806170001
               WHERE end_time >= (SELECT MIN(end_time) FROM fdr.p200806170001) + ''5 minute''::INTERVAL
                 AND end_time < (SELECT MIN(end_time) FROM fdr.p200806170001) + ''10 minute''::INTERVAL'
            )
   AS t1 (device_id      INTEGER,
          flow_id        BIGINT,
          src_ip         BYTEA,
          dst_ip         BYTEA,
          interface_in   SMALLINT,                 
          interface_out  SMALLINT,                 
          pkts           INTEGER,                  
          bytes          BIGINT,                   
          start_time     TIMESTAMP WITH TIME ZONE, 
          end_time       TIMESTAMP WITH TIME ZONE, 
          src_port       INTEGER,                  
          dst_port       INTEGER,                  
          flow_policy_id SMALLINT,                 
          tcp_flag_id    SMALLINT,                 
          protocol_id    SMALLINT,                 
          tos            SMALLINT,                 
          service_id     SMALLINT,                 
          priority_id    SMALLINT,                 
          retrans_bytes  INTEGER,                  
          vlan_id        SMALLINT,                 
          time_to_live   SMALLINT,                 
          ftype_num      SMALLINT,                 
          measure_1      INTEGER,                  
          measure_2      INTEGER,                  
          measure_3      INTEGER
        )
;

-- INSERT 0 995375
-- Time: 163875.000 ms
-- SELECT COUNT(*) FROM fdr.p200806170001;
-- +---------+
-- | 1978677 |
-- +---------+

*/
