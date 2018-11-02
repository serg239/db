-- ======================
-- get_top_n_flow_details =================================
-- ======================

CREATE OR REPLACE FUNCTION get_top_n_flow_details 
(
  group_id        INTEGER,
  site_id         INTEGER,
  application_id  INTEGER,
  class_id        INTEGER,
  flow_type       VARCHAR, 
  measure_type    VARCHAR, 
  dim_value       VARCHAR,
  start_time      TIMESTAMPTZ, 
  end_time        TIMESTAMPTZ, 
  table_prefix    VARCHAR 
)
RETURNS SETOF fdr.top_n_flow_details_type
AS
$body$
/*
  Input:
    * Device Group Id. Values: 0 means ALL groups
    * Site Id.         Values: 0 means ALL sites
    * Application Id.  Values: 0 means ALL applications
    * Class Id.        Values: 0 means ALL classes
    * Flow Type.       Values: ['talker'|'listener'|'vlan'|'dscp'|'service']
    * Measure Type.    Values: ['bytes'|'pkts']
    * Dimension Value: Talker   => src_ip value
                       Listener => dst_ip value
                       VLAN     => vlan_id value
                       DSCP     => tos value
                       Service  => name of the service
    * Start Time(stamp) with Time Zone
    * End Time(stamp) with Time Zone
    * Table Prefix.    Values: ['n'|'p']
  Output:
    * SETOF fdr.top_n_flow_details_type
    (
      entity            VARCHAR,                        <-- FLW
      bytes             INT8,                           <-- FLW
      pkts              INT8,                           <-- FLW
      flows             INT8,                           <-- FLW
      efficiency_pct    NUMERIC(5, 2),                  <-- FLW
      avg_total_delay   NUMERIC(14, 2),  -- 2008.10.20  <-- RTM
      avg_server_delay  NUMERIC(14, 2),  -- 2008.10.20  <-- RTM
      total_rtm_trans   INT8,                           <-- RTM
      pet_server        INT8,                           <-- PET
      pet_client        INT8                            <-- PET  
    );
  Examples:
    -- RKTR2. TALKER
    SELECT * FROM fdr.get_top_n_flow_details (1, 0, 0, 0, 'talker', 'bytes', '75.0.53.208', '2009-01-13 13:00:00-08', '2009-01-13 15:00:00-08', 'p');
    +-------------+----------+-------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    |   entity    |  bytes   | pkts  | flows | efficiency_pct | avg_total_delay | avg_server_delay | total_rtm_trans | pet_server | pet_client |
    +-------------+----------+-------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    | 72.0.53.208 | 13549128 | 10184 |    32 |          99.96 |            0.00 |             0.00 |               0 |      92306 |          6 |
    +-------------+----------+-------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    -- RKTR2. LISTENER
    SELECT * FROM fdr.get_top_n_flow_details (1, 0, 0, 0, 'listener', 'bytes', '75.0.53.208', '2009-01-13 13:00:00-08', '2009-01-13 15:00:00-08', 'p');
    +-------------+--------+-------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    |   entity    | bytes  | pkts  | flows | efficiency_pct | avg_total_delay | avg_server_delay | total_rtm_trans | pet_server | pet_client |
    +-------------+--------+-------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    | 72.0.53.208 | 547312 | 10196 |    32 |          99.89 |        23413.16 |         11431.30 |              96 |          0 |          0 |
    +-------------+--------+-------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    -- DSCP
    SELECT * FROM fdr.get_top_n_flow_details (1, 0, 0, 0, 'dscp', 'bytes', '0', '2009-01-13 13:00:00-08', '2009-01-13 15:00:00-08', 'p');
    +--------------+----------+--------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    |    entity    |  bytes   |  pkts  | flows | efficiency_pct | avg_total_delay | avg_server_delay | total_rtm_trans | pet_server | pet_client |
    +--------------+----------+--------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    | 10.9.88.140  | 62421358 | 354788 |  5483 |         100.00 |            8.08 |             7.01 |             137 |          0 |          0 |
    | 188.88.1.110 | 13839003 |  48627 |  2240 |         100.00 |          118.30 |            11.16 |              50 |          0 |          0 |
    | 75.0.13.27   | 13600700 |  10300 |   104 |          99.89 |            0.00 |             0.00 |               0 |      91552 |         10 |
    | 75.0.13.119  | 13600492 |  10304 |   104 |          99.89 |            0.00 |             0.00 |               0 |      91065 |          7 |
    | 75.0.5.199   | 13599368 |  10296 |   104 |          99.90 |            0.00 |             0.00 |               0 |      92013 |         10 |
    | 75.0.22.142  | 13597992 |  10300 |   104 |          99.91 |            0.00 |             0.00 |               0 |      91563 |          9 |
    . . .
    -- VLAN
    SELECT * FROM fdr.get_top_n_flow_details (1, 0, 0, 0, 'vlan', 'bytes', '0', '2009-01-13 13:00:00-08', '2009:00-08', 'p');
    +--------------+----------+--------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    |    entity    |  bytes   |  pkts  | flows | efficiency_pct | avg_total_delay | avg_server_delay | total_rtm_trans | pet_server | pet_client |
    +--------------+----------+--------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    | 10.9.88.140  | 62421358 | 354788 |  5483 |         100.00 |            8.08 |             7.01 |             137 |          0 |          0 |
    | 188.88.1.110 | 13839003 |  48627 |  2240 |         100.00 |          118.30 |            11.16 |              50 |          0 |          0 |
    | 75.0.13.27   | 13600700 |  10300 |   104 |          99.89 |            0.00 |             0.00 |               0 |      91552 |         10 |
    | 75.0.13.119  | 13600492 |  10304 |   104 |          99.89 |            0.00 |             0.00 |               0 |      91065 |          7 |
    | 75.0.5.199   | 13599368 |  10296 |   104 |          99.90 |            0.00 |             0.00 |               0 |      92013 |         10 |
    | 75.0.22.142  | 13597992 |  10300 |   104 |          99.91 |            0.00 |             0.00 |               0 |      91563 |          9 |
    . . .
    -- SERVICE
    SELECT * FROM fdr.get_top_n_flow_details (1, 0, 0, 0, 'service', 'bytes', 'HTTP', '2009-01-13 13:00:00-08', '2009-01-13 15:00:00-08', 'p');
    +--------------+----------+-------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    |    entity    |  bytes   | pkts  | flows | efficiency_pct | avg_total_delay | avg_server_delay | total_rtm_trans | pet_server | pet_client |
    +--------------+----------+-------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    | 188.88.1.110 | 13725406 | 47446 |  1327 |         100.00 |            0.00 |             0.00 |               0 |          0 |          0 |
    | 75.0.53.208  | 13078871 |  9573 |     9 |          99.95 |            0.00 |             0.00 |               0 |      68740 |          3 |
    | 75.0.38.164  | 12915940 |  9036 |     4 |          99.96 |            0.00 |             0.00 |               0 |      45659 |          0 |
    | 75.0.65.3    | 12910180 |  9032 |     4 |         100.00 |            0.00 |             0.00 |               0 |      44591 |          0 |
    | 75.0.49.192  | 12664118 |  9290 |     6 |          99.85 |            0.00 |             0.00 |               0 |      45587 |          3 |
    | 75.0.37.23   | 12663976 |  9276 |     4 |          99.85 |            0.00 |             0.00 |               0 |      34641 |          2 |
    | 75.0.36.31   | 12663592 |  9272 |     4 |          99.85 |            0.00 |             0.00 |               0 |      45373 |          3 |
    . . .
    -- RAW DATA
    SELECT * FROM fdr.get_top_n_flow_details (1, 0, 0, 0, 'talker', 'bytes', '75.0.53.208', '2009-01-13 14:00:00-08', '2009-01-13 14:15:00-08', 'p');
    +-------------+----------+------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    |   entity    |  bytes   | pkts | flows | efficiency_pct | avg_total_delay | avg_server_delay | total_rtm_trans | pet_server | pet_client |
    +-------------+----------+------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    | 72.0.53.208 | 12654508 | 9340 |    12 |          99.95 |            0.00 |             0.00 |               0 |      45149 |          3 |
    +-------------+----------+------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    -- NETFLOW5. TALKER
    SELECT * FROM fdr.get_top_n_flow_details (1, 0, 0, 0, 'talker', 'bytes', '75.0.53.208', '2009-01-13 13:00:00-08', '2009-01-13 15:00:00-08', 'n');
    +-------------+---------+------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    |   entity    |  bytes  | pkts | flows | efficiency_pct | avg_total_delay | avg_server_delay | total_rtm_trans | pet_server | pet_client |
    +-------------+---------+------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
    | 72.0.53.208 | 3387282 | 2546 |     8 |         100.00 |            0.00 |             0.00 |               0 |          0 |          0 |
    +-------------+---------+------+-------+----------------+-----------------+------------------+-----------------+------------+------------+
*/
DECLARE
  -- Constants
  FUNCTION_NAME   CONSTANT VARCHAR  := 'get_top_n_flow_details';
  SCHEMA_NAME     CONSTANT CHAR(3)  := 'fdr';  -- Schema Name
  RTM_FTYPE_NUM   CONSTANT SMALLINT := 4;      -- RTM Type Number
  PET_FTYPE_NUM   CONSTANT SMALLINT := 5;      -- PET Type Number
  RAW_TNAME_LEN   CONSTANT SMALLINT := 13;
  MAX_ROW_NUMS    CONSTANT SMALLINT := 5000;
  LF              CONSTANT CHAR(1)  := CHR(10);
  TITLE           CONSTANT CHAR(10) := REPEAT('*', 10);
  DEBUG_TNAME     CONSTANT CHAR(13) := 'fdr.test_temp';
  -- Variables
  -- Periods
  is_prd_def      BOOLEAN := FALSE;
  period_stmt     TEXT;
  period_rec      metrics.table_periods_type%ROWTYPE;
  -- Temporary table
  temp_tname      VARCHAR(32);
  --
  cache_size      INTEGER;
  nestloop        VARCHAR(3);
  -- Fields: $5 --> flow_type
  field_name      VARCHAR(10) := CASE WHEN ($5 = 'talker')   THEN 'src_ip'
                                      WHEN ($5 = 'listener') THEN 'dst_ip'
                                      WHEN ($5 = 'vlan')     THEN 'vlan_id'
                                      WHEN ($5 = 'dscp')     THEN 'tos'
                                      WHEN ($5 = 'service')  THEN 'service_id'
                                      ELSE 'undef'
                                 END;
  peer_field_name VARCHAR(6) := CASE WHEN ($5 = 'talker')   THEN 'dst_ip'
                                     WHEN ($5 = 'listener') THEN 'src_ip'
                                     WHEN ($5 = 'vlan')     THEN 'src_ip'
                                     WHEN ($5 = 'dscp')     THEN 'src_ip'
                                     WHEN ($5 = 'service')  THEN 'src_ip'
                                     ELSE 'undef'
                                END;
  --
  ip_bytea_str    VARCHAR;
  is_ip_bytea     BOOLEAN := FALSE;
  -- Statements
  join_group_stmt TEXT := '';
  join_csa_stmt   TEXT := ''; 
  sql_stmt        TEXT;
  exec_stmt       TEXT := ''; -- !!!
  err_stmt        TEXT := '';
  -- Performance
  is_perf         BOOLEAN := FALSE;
  p_beg_time      TIMESTAMPTZ;
  p_params        TEXT;
  p_perf_id       INTEGER;
  -- Result
  result          fdr.top_n_flow_details_type%ROWTYPE;
  is_debug        BOOLEAN := FALSE; -- TRUE;
BEGIN            

  IF field_name = 'undef' THEN
    RAISE EXCEPTION '%', 'Wrong flow_type parameter = ['||flow_type||']';
  END IF;
  
  IF ((application_id > 0) OR (class_id > 0)) AND NOT (flow_type = 'talker' OR flow_type = 'listener') THEN
    RAISE EXCEPTION '%', 'Wrong flow_type parameter = ['||flow_type||'] for Applications or Classes.';
  END IF;

  IF NOT (measure_type = 'bytes' OR measure_type = 'pkts') THEN
    RAISE EXCEPTION '%', 'Wrong measure_type parameter = ['||measure_type||']';
  END IF;

  IF (flow_type = 'service' AND table_prefix <> 'p') THEN
    RAISE EXCEPTION '%', 'Wrong flow_type parameter = ['||flow_type||'] for '''||table_prefix||''' flows.';
  END IF;

  IF (metrics.unix_timestamp(end_time) >= metrics.unix_timestamp(start_time)) THEN

    -- Performance testing
    SELECT is_started FROM metrics.components WHERE name = 'check_performance' INTO is_perf;
    IF is_perf THEN
      SELECT NOW() INTO p_beg_time;
      p_params := 
      'group_id  ='||group_id||','||LF||
      'site_id   ='||site_id||','||LF||
      'appl_id   ='||application_id||','||LF||
      'class_id  ='||class_id||','||LF||
      'flow_type ='''||flow_type||''','||LF||
      'meas_type ='''||measure_type||''','||LF||
      'dim_value ='''||dim_value||''','||LF||
      'start_time='''||start_time||''','||LF||
      'end_time  ='''||end_time||''','||LF||
      'tbl_prefix='''||table_prefix||'''';
      INSERT INTO metrics.perfs (func_name, params, beg_time) VALUES 
      (FUNCTION_NAME, p_params, p_beg_time)
      RETURNING perf_id INTO p_perf_id;
    END IF;

    -- ====================
    -- 1. Get Time Periods
    -- ====================
    err_stmt := 'Couldn''t Get Set Of Periods.';
    period_stmt := 'SELECT table_name, period_id, period_name, start_time '||
                   'FROM metrics.get_set_of_periods ('||
                   quote_literal(SCHEMA_NAME)||', '||
                   quote_literal(start_time)||', '||
                   quote_literal(end_time)||', '||
                   quote_literal(table_prefix)||', '||
                   'FALSE)';  -- optimization
    -- Check the set of periods
    FOR period_rec IN EXECUTE period_stmt 
    LOOP
      IF CHAR_LENGTH(period_rec.table_name) > 1 THEN
        is_prd_def := TRUE;
        EXIT;  
      ELSE
        -- Exception if period is undefined 
        RAISE EXCEPTION 'Undefined period.';
      END IF;  
    END LOOP;

    IF is_debug THEN
      -- Check Periods
      RAISE NOTICE '%', TITLE||' Periods '||TITLE;
      FOR period_rec IN EXECUTE period_stmt
      LOOP
        RAISE NOTICE '% | % | % | %', period_rec.table_name, period_rec.period_id, period_rec.period_name, period_rec.start_time;
      END LOOP;
    END IF;  

    IF is_prd_def THEN

      -- =========================================
      -- 2. Prepare the Statements and Environment
      -- =========================================

      -- Prepare the JOIN GROUP statement (for "pt" table)
      IF (group_id > 0) THEN
        join_group_stmt := 'JOIN metrics.devices dv'||LF||
                           'ON pt.device_id = dv.device_id'||LF||
                           'JOIN metrics.group_devices gd'||LF||
                           'ON (dv.device_id = gd.device_id'||LF||
                           'AND gd.group_id = '||group_id||')'||LF;
      END IF;

      -- Prepare the JOIN Sites, Applications, and/or Classes
      IF (site_id > 0) AND (application_id = 0) THEN
        -- Sites (Classes in the Site Definition)
        join_csa_stmt := 'JOIN metrics.dev_classes dc'||LF||
                         'ON (pt.device_id = dc.device_id'||LF||
                         'AND pt.ud_class_id = dc.ud_class_id)'||LF||
                         'JOIN metrics.site_classes sc'||LF||
                         'ON (dc.class_id = sc.class_id'||LF||
                         'AND sc.site_id = '||site_id||')'||LF;
      ELSIF (application_id > 0) AND (site_id = 0) THEN
        -- Applications (Classes in the Application Definition)
        join_csa_stmt := 'JOIN metrics.dev_classes dc'||LF||
                         'ON (pt.device_id = dc.device_id'||LF||
                         'AND pt.ud_class_id = dc.ud_class_id)'||LF||
                         'JOIN metrics.application_classes ac'||LF||
                         'ON (dc.class_id = ac.class_id'||LF||
                         'AND ac.application_id = '||application_id||')'||LF;
      ELSIF (site_id = 0) AND (application_id = 0) AND (class_id > 0) THEN
        -- Classes (if site_id = 0 and application_id = 0)
        join_csa_stmt := 'JOIN metrics.dev_classes dc'||LF||
                         'ON (pt.device_id = dc.device_id'||LF||
                         'AND pt.ud_class_id = dc.ud_class_id)'||LF||
                         'JOIN metrics.classes cl'||LF||
                         'ON (dc.class_id = cl.class_id'||LF||
                         'AND cl.class_id = '||class_id||')'||LF;
      END IF;

      -- Prepare BYTEA value for IP Address
      IF (field_name = 'src_ip') OR (field_name = 'dst_ip') THEN
        BEGIN
          SELECT INTO ip_bytea_str metrics.inet_text2bytea(dim_value::TEXT);
          IF POSITION (E'\\' IN ip_bytea_str) > 0 THEN
            ip_bytea_str := REPLACE (ip_bytea_str, E'\\', E'\\\\');
          END IF;
          IF POSITION (E'''' IN ip_bytea_str) > 0 THEN
            ip_bytea_str := REPLACE (ip_bytea_str, '''', E'\\''');
          END IF;
          is_ip_bytea := TRUE;
          EXCEPTION
            WHEN OTHERS THEN
              BEGIN
                is_ip_bytea := FALSE;
              END;
        END;
      END IF;

      -- EFFECTIVE_CACHE_SIZE
      -- Save the current value of the effective_cache_size
      SELECT setting FROM pg_settings WHERE name = 'effective_cache_size' INTO cache_size;
      exec_stmt := 'SET effective_cache_size = 262144;'; --> 1GB [131072 --> 1GB; 262144 --> 2GB; 524288 --> 4GB]
      EXECUTE exec_stmt;

      -- NESTLOOP
      SELECT setting FROM pg_settings WHERE name = 'enable_nestloop' INTO nestloop;
      IF nestloop = 'on' THEN
        exec_stmt := 'SET enable_nestloop TO off;';
        EXECUTE exec_stmt;
      END IF;

/*
    -- HASHAGG
    SELECT setting FROM pg_settings WHERE name = 'enable_hashagg' INTO hashagg;
    IF hashagg = 'on' THEN
      exec_stmt := 'SET enable_hashagg TO off;';
      EXECUTE exec_stmt;
    END IF;

    -- HASHJOIN
    SELECT setting FROM pg_settings WHERE name = 'enable_hashjoin' INTO hashjoin;
    IF hashjoin = 'on' THEN
      exec_stmt := 'SET enable_hashjoin TO off;';
      EXECUTE exec_stmt;
    END IF;
*/

      -- ============================
      -- 3. Create a Temporary table
      -- ============================
      SELECT TRUNC(1000000000000000*RANDOM())::TEXT INTO temp_tname;  -- Generate a Random Table Name
      exec_stmt := 'CREATE TEMPORARY TABLE '||quote_ident(temp_tname)||LF||
                   '(entity VARCHAR,'||LF||
                   'bytes BIGINT,'||LF||
                   'pkts BIGINT,'||LF||
                   'flows BIGINT,'||LF||
                   'retrans_bytes BIGINT,'||LF||
                   'rtm_total_delay BIGINT DEFAULT 0,'||LF||
                   'rtm_server_delay BIGINT DEFAULT 0,'||LF||
                   'rtm_transactions BIGINT DEFAULT 0,'||LF||
                   'pet_server BIGINT DEFAULT 0,'||LF||
                   'pet_client BIGINT DEFAULT 0)'||LF||
                   'WITHOUT OIDS;';

      IF NOT is_debug THEN
        err_stmt := 'Could not create Temporary Table.';
        EXECUTE exec_stmt;
      ELSE
        RAISE NOTICE '%', TITLE||' Create a Temporary table '||TITLE;
        exec_stmt := LF||'DROP TABLE IF EXISTS '||DEBUG_TNAME||';'||LF||exec_stmt;
        exec_stmt := REPLACE (exec_stmt, 'TEMPORARY TABLE '||quote_ident(temp_tname), 'TABLE '||DEBUG_TNAME);
        RAISE NOTICE '%', exec_stmt;
      END IF;

      -- =======================================================
      -- 4. Get Top N values of Enities for a given 'flow_type'
      -- =======================================================
      err_stmt := 'Couldn''t Get Top N Values.';
      exec_stmt := 'INSERT INTO '||quote_ident(temp_tname)||' (entity, '||measure_type||')'||LF||
                   'SELECT res.entity AS entity,'||LF||
                   'SUM(res.'||measure_type||') AS '||measure_type||LF||
                   'FROM ('||LF;
      FOR period_rec IN EXECUTE period_stmt
      LOOP
        IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
          sql_stmt := 'SELECT pt.'||peer_field_name||' AS entity,'||LF;
        ELSE
          sql_stmt := 'SELECT metrics.inet_bytea2text(pt.'||peer_field_name||') AS entity,'||LF;
        END IF;
        
        sql_stmt := sql_stmt||
                    'SUM(pt.'||measure_type||') AS '||measure_type||LF||
                    'FROM '||SCHEMA_NAME||'.'||period_rec.table_name||' pt'||LF||
                    join_group_stmt;

        IF (table_prefix = 'p') THEN
          -- PKTR2
          sql_stmt := sql_stmt ||
                      join_csa_stmt;
        END IF;  -- IF table_prefix = 'p'

        -- WHERE Conditions
        IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
          --  Rollup tables
          IF period_rec.period_id > 0 THEN
            sql_stmt := sql_stmt||
                        'WHERE pt.period_id = '||period_rec.period_id||LF;
          ELSE
            sql_stmt := sql_stmt||
                        'WHERE pt.period_id > 0'||LF;
          END IF;
          -- Dimension Conditions 
          -- Note: Service info does not exist in the Netflow5 data - it was checked before 
          IF (flow_type = 'service') THEN
            sql_stmt := sql_stmt||
                        'AND pt.'||field_name||' = (SELECT ord_id FROM metrics.services WHERE name = '''||dim_value||''')'||LF;
          ELSE
            sql_stmt := sql_stmt||
                        'AND pt.'||field_name||' = '''||dim_value||''''||LF;
          END IF;
        ELSE
          -- RAW tables
          IF (field_name = 'src_ip') OR (field_name = 'dst_ip') THEN
            IF is_ip_bytea THEN
              sql_stmt := sql_stmt||
                          'WHERE pt.'||field_name||' = E'''||ip_bytea_str||'''::BYTEA'||LF;
            ELSE
              sql_stmt := sql_stmt||
                          'WHERE pt.'||field_name||' = metrics.inet_text2bytea('''||dim_value||''')'||LF;
            END IF;
          ELSE
            -- Dimension condition
            IF (flow_type = 'service') THEN
              sql_stmt := sql_stmt||
                          'WHERE pt.'||field_name||' = (SELECT ord_id FROM metrics.services WHERE name = '''||dim_value||''')'||LF;
            ELSE
              sql_stmt := sql_stmt||
                          'WHERE pt.'||field_name||' = '''||dim_value||''''||LF;
            END IF;
          END IF;

        END IF;

        sql_stmt := sql_stmt||
                    'GROUP BY entity'||LF;
        exec_stmt := exec_stmt||sql_stmt||'UNION ALL'||LF;

      END LOOP;

      exec_stmt := SUBSTR(exec_stmt, 1, CHAR_LENGTH(exec_stmt) - CHAR_LENGTH('UNION ALL') - CHAR_LENGTH(LF));
      exec_stmt := exec_stmt||
                   ') res'||LF||
                   'GROUP BY res.entity'||LF||
                   'ORDER BY '||measure_type||' DESC'||LF||
                   'LIMIT '||MAX_ROW_NUMS||';';

      IF NOT is_debug THEN
        -- Get the Result Set
        err_stmt := 'Couldn''t Get Top N Measured Values.';
        EXECUTE exec_stmt;
      ELSE  
        -- Check the Result Statement
        RAISE NOTICE '%', TITLE||' Statement for Top N Measured Values '||TITLE;
        exec_stmt := LF||REPLACE (exec_stmt, quote_ident(temp_tname), DEBUG_TNAME);
        RAISE NOTICE '%', exec_stmt;
      END IF;

      -- ======================================================
      -- 5. Get FLOW Values for a founded Top N Entities
      -- ======================================================
      err_stmt := 'Couldn''t Create SQL statement for Flow Values.';
      exec_stmt := 'UPDATE ONLY '||quote_ident(temp_tname)||' AS tt'||LF;
      IF measure_type = 'bytes' THEN
        exec_stmt := exec_stmt||
                     'SET pkts = res.pkts,'||LF;
      ELSIF measure_type = 'pkts' THEN
        exec_stmt := exec_stmt||
                     'SET bytes = res.bytes,'||LF;
      END IF;
      exec_stmt := exec_stmt||
                   'flows = res.flows,'||LF||
                   'retrans_bytes = res.retrans_bytes'||LF||
                   'FROM ('||LF||
                   'SELECT flw.entity AS entity,'||LF;
      IF measure_type = 'bytes' THEN
        exec_stmt := exec_stmt||
                     'SUM(flw.pkts) AS pkts,'||LF;
      ELSIF measure_type = 'pkts' THEN
        exec_stmt := exec_stmt||
                     'SUM(flw.bytes) AS bytes,'||LF;
      END IF;
      exec_stmt := exec_stmt||
                   'SUM(flw.flows) AS flows,'||LF||
                   'SUM(retrans_bytes) AS retrans_bytes'||LF||
                   'FROM ('||LF;
      FOR period_rec IN EXECUTE period_stmt
      LOOP
        -- Entity
        IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
          sql_stmt := 'SELECT pt.'||peer_field_name||' AS entity,'||LF;
        ELSE
          sql_stmt := 'SELECT metrics.inet_bytea2text(pt.'||peer_field_name||') AS entity,'||LF;
        END IF;
        -- Bytes or Pkts
        IF measure_type = 'bytes' THEN
          sql_stmt := sql_stmt||
                      'SUM(pt.pkts) AS pkts,'||LF;
        ELSIF measure_type = 'pkts' THEN
          sql_stmt := sql_stmt||
                      'SUM(pt.bytes) AS bytes,'||LF;
        END IF;
        -- Flows
        IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
          sql_stmt := sql_stmt||
                      'SUM(pt.flow_num) AS flows,'||LF;
        ELSE
          sql_stmt := sql_stmt||
                      'COUNT(pt.*) AS flows,'||LF;
        END IF;
        -- Retrans_bytes for 'p' tables only
        IF (table_prefix = 'p') THEN
          sql_stmt := sql_stmt||
                      'SUM(pt.retrans_bytes) AS retrans_bytes'||LF;
        ELSE
          sql_stmt := sql_stmt||
                      '0 AS retrans_bytes'||LF;
        END IF;
        -- Conditions
        sql_stmt := sql_stmt||
                    'FROM '||SCHEMA_NAME||'.'||period_rec.table_name||' pt'||LF||
                    join_group_stmt;

        IF (table_prefix = 'p') THEN
          -- PKTR2
          sql_stmt := sql_stmt ||
                      join_csa_stmt;
        END IF;  -- IF table_prefix = 'p'

        -- WHERE Conditions
        IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
          --  Rollup tables
          IF period_rec.period_id > 0 THEN
            sql_stmt := sql_stmt||
                        'WHERE pt.period_id = '||period_rec.period_id||LF;
          ELSE
            -- the whole table
            sql_stmt := sql_stmt||
                        'WHERE pt.period_id > 0'||LF;
          END IF;
          -- Dimension Conditions 
          -- Note: Service info does not exist in the Netflow5 data - already checked before 
          IF (flow_type = 'service') THEN
            sql_stmt := sql_stmt||
                        'AND pt.'||field_name||' = (SELECT ord_id FROM metrics.services WHERE name = '''||dim_value||''')'||LF;
          ELSE
            sql_stmt := sql_stmt||
                        'AND pt.'||field_name||' = '''||dim_value||''''||LF;
          END IF;
        ELSE
          -- RAW tables
          IF (field_name = 'src_ip') OR (field_name = 'dst_ip') THEN
            IF is_ip_bytea THEN
              sql_stmt := sql_stmt||
                          'WHERE pt.'||field_name||' = E'''||ip_bytea_str||'''::BYTEA'||LF;
            ELSE
              sql_stmt := sql_stmt||
                          'WHERE pt.'||field_name||' = metrics.inet_text2bytea('''||dim_value||''')'||LF;
            END IF;
          ELSE
            -- Dimension condition
            IF (flow_type = 'service') THEN
              sql_stmt := sql_stmt||
                          'WHERE pt.'||field_name||' = (SELECT ord_id FROM metrics.services WHERE name = '''||dim_value||''')'||LF;
            ELSE
              sql_stmt := sql_stmt||
                          'WHERE pt.'||field_name||' = '''||dim_value||''''||LF;
            END IF;
          END IF;
        END IF;

        sql_stmt := sql_stmt||
                    'GROUP BY entity'||LF;
        exec_stmt := exec_stmt||sql_stmt||'UNION ALL'||LF;

      END LOOP;

      exec_stmt := SUBSTR(exec_stmt, 1, CHAR_LENGTH(exec_stmt) - CHAR_LENGTH('UNION ALL') - CHAR_LENGTH(LF));
      exec_stmt := exec_stmt||
                   ') flw'||LF||
                   'GROUP BY entity'||LF||
                   ') res'||LF||
                   'WHERE res.entity = tt.entity;';

      IF NOT is_debug THEN
        err_stmt := 'Couldn''t Get the Flow Values.';
        EXECUTE exec_stmt;
      ELSE  
        RAISE NOTICE '%', TITLE||' Statement for FLOW Values '||TITLE;
        exec_stmt := LF||REPLACE(exec_stmt, quote_ident(temp_tname), DEBUG_TNAME);
        RAISE NOTICE '%', exec_stmt;
      END IF;   

      -- RTM and Pet values for 'p' tables only 
      IF (table_prefix = 'p') THEN

        -- =========================================================
        -- 7. Get RTM values for a founded MAX_ROW_NUMS FLOW values
        -- =========================================================

        err_stmt := 'Couldn''t Create SQL statement for RTM values.';
        exec_stmt := 'UPDATE ONLY '||quote_ident(temp_tname)||' AS tt'||LF||
                     'SET rtm_total_delay = res.rtm_total_delay,'||LF||
                     'rtm_server_delay = res.rtm_server_delay,'||LF||
                     'rtm_transactions = res.rtm_transactions'||LF||
                     'FROM ('||LF||
                     'SELECT rtm.entity AS entity,'||LF||
                     'SUM(rtm.rtm_total_delay) AS rtm_total_delay,'||LF||
                     'SUM(rtm.rtm_server_delay) AS rtm_server_delay,'||LF||
                     'SUM(rtm.rtm_transactions) AS rtm_transactions'||LF||
                     'FROM ('||LF;

        FOR period_rec IN EXECUTE period_stmt
        LOOP
          -- Entity
          IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
            sql_stmt := 'SELECT pt.'||peer_field_name||' AS entity,'||LF;
          ELSE
            sql_stmt := 'SELECT metrics.inet_bytea2text(pt.'||peer_field_name||') AS entity,'||LF;
          END IF;
          sql_stmt := sql_stmt||
                      'SUM(pt.measure_1) AS rtm_total_delay,'||LF||
                      'SUM(pt.measure_2) AS rtm_server_delay,'||LF||
                      'SUM(pt.measure_3) AS rtm_transactions'||LF||
                      'FROM '||SCHEMA_NAME||'.'||period_rec.table_name||' pt'||LF||
                      join_group_stmt||
                      join_csa_stmt||
                      'WHERE pt.ftype_num = '||RTM_FTYPE_NUM||LF;          -- RTM FLOW TYPE

          -- WHERE Conditions
          IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
            --  Rollup tables
            IF period_rec.period_id > 0 THEN
              sql_stmt := sql_stmt||
                          'AND pt.period_id = '||period_rec.period_id||LF;
            ELSE
              sql_stmt := sql_stmt||
                          'AND pt.period_id > 0'||LF;
            END IF;
            -- Dimension Conditions 
            -- Note: Service info does not exist in the Netflow5 data - already checked before 
            IF (flow_type = 'service') THEN
              sql_stmt := sql_stmt||
                          'AND pt.'||field_name||' = (SELECT ord_id FROM metrics.services WHERE name = '''||dim_value||''')'||LF;
            ELSE
              sql_stmt := sql_stmt||
                          'AND pt.'||field_name||' = '''||dim_value||''''||LF;
            END IF;
          ELSE
            -- RAW tables
            IF (field_name = 'src_ip') OR (field_name = 'dst_ip') THEN
              IF is_ip_bytea THEN
                sql_stmt := sql_stmt||
                            'WHERE pt.'||field_name||' = E'''||ip_bytea_str||'''::BYTEA'||LF;
              ELSE
                sql_stmt := sql_stmt||
                            'WHERE pt.'||field_name||' = metrics.inet_text2bytea('''||dim_value||''')'||LF;
              END IF;
            ELSE
              -- Dimension condition
              IF (flow_type = 'service') THEN
                sql_stmt := sql_stmt||
                            'AND pt.'||field_name||' = (SELECT ord_id FROM metrics.services WHERE name = '''||dim_value||''')'||LF;
              ELSE
                sql_stmt := sql_stmt||
                            'AND pt.'||field_name||' = '''||dim_value||''''||LF;
              END IF;
            END IF;
          END IF;

        sql_stmt := sql_stmt||
                    'GROUP BY entity'||LF;
        exec_stmt := exec_stmt||sql_stmt||'UNION ALL'||LF;
      END LOOP;

      exec_stmt := SUBSTR(exec_stmt, 1, CHAR_LENGTH(exec_stmt) - CHAR_LENGTH('UNION ALL') - CHAR_LENGTH(LF));
      exec_stmt := exec_stmt||
                   ') rtm'||LF||
                   'GROUP BY entity'||LF||
                   ') res'||LF||
                   'WHERE res.entity = tt.entity;';

        IF NOT is_debug THEN
          err_stmt := 'Couldn''t Get the RTM Values.';
          EXECUTE exec_stmt;
        ELSE  
          RAISE NOTICE '%', TITLE||' RTM Result Statement '||TITLE;
          exec_stmt := LF||REPLACE(exec_stmt, quote_ident(temp_tname), DEBUG_TNAME);
          RAISE NOTICE '%', exec_stmt;
        END IF;   

        -- =========================================================
        -- 8. Get PET values for a founded MAX_ROW_NUMS FLOW values
        -- =========================================================

        err_stmt := 'Couldn''t Create SQL statement for PET values.';
        exec_stmt := 'UPDATE ONLY '||quote_ident(temp_tname)||' AS tt'||LF||
                     'SET pet_server = res.pet_server,'||LF||
                     'pet_client = res.pet_client'||LF||
                     'FROM ('||LF||
                     'SELECT pet.entity AS entity,'||LF||
                     'SUM(pet.pet_server) AS pet_server,'||LF||
                     'SUM(pet.pet_client) AS pet_client'||LF||
                     'FROM ('||LF;

        FOR period_rec IN EXECUTE period_stmt
        LOOP
          -- Entity
          IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
            sql_stmt := 'SELECT pt.'||peer_field_name||' AS entity,'||LF;
          ELSE
            sql_stmt := 'SELECT metrics.inet_bytea2text(pt.'||peer_field_name||') AS entity,'||LF;
          END IF;

          sql_stmt := sql_stmt||
                      'SUM(pt.measure_2) AS pet_server,'||LF||
                      'SUM(pt.measure_3) AS pet_client'||LF||
                      'FROM '||SCHEMA_NAME||'.'||period_rec.table_name||' pt'||LF||
                      join_group_stmt||
                      join_csa_stmt||
                      'WHERE pt.ftype_num = '||PET_FTYPE_NUM||LF;           -- PET FLOW TYPE

          -- WHERE Conditions
          IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
            --  Rollup tables
            IF period_rec.period_id > 0 THEN
              sql_stmt := sql_stmt||'AND pt.period_id = '||period_rec.period_id||LF;
            ELSE
              -- the whole table
              sql_stmt := sql_stmt||'AND pt.period_id > 0'||LF;
            END IF;
            -- Dimension Conditions 
            -- Note: Service info does not exist in the Netflow5 data - it was checked before 
            IF (flow_type = 'service') THEN
              sql_stmt := sql_stmt||
                          'AND pt.'||field_name||' = (SELECT ord_id FROM metrics.services WHERE name = '''||dim_value||''')'||LF;
            ELSE
              sql_stmt := sql_stmt|| 
                          'AND pt.'||field_name||' = '''||dim_value||''''||LF;
            END IF;
          ELSE
            -- RAW tables
            IF (field_name = 'src_ip') OR (field_name = 'dst_ip') THEN
              IF is_ip_bytea THEN
                sql_stmt := sql_stmt||
                            'WHERE pt.'||field_name||' = E'''||ip_bytea_str||'''::BYTEA'||LF;
              ELSE
                sql_stmt := sql_stmt||
                            'WHERE pt.'||field_name||' = metrics.inet_text2bytea('''||dim_value||''')'||LF;
              END IF;
            ELSE
              -- Dimension condition
              IF (flow_type = 'service') THEN
                sql_stmt := sql_stmt||
                            'AND pt.'||field_name||' = (SELECT ord_id FROM metrics.services WHERE name = '''||dim_value||''')'||LF;
              ELSE
                sql_stmt := sql_stmt||
                            'AND pt.'||field_name||' = '''||dim_value||''''||LF;
              END IF;
            END IF;
          END IF;

          sql_stmt := sql_stmt||
                      'GROUP BY entity'||LF;

          exec_stmt := exec_stmt||sql_stmt||'UNION ALL'||LF;

        END LOOP;

        exec_stmt := SUBSTR(exec_stmt, 1, CHAR_LENGTH(exec_stmt) - CHAR_LENGTH('UNION ALL') - CHAR_LENGTH(LF));
        exec_stmt := exec_stmt||
                   ') pet'||LF||
                   'GROUP BY entity'||LF||
                   ') res'||LF||
                   'WHERE res.entity = tt.entity;';

        IF NOT is_debug THEN
          err_stmt := 'Couldn''t Get the PET Values.';
          EXECUTE exec_stmt;
        ELSE  
          RAISE NOTICE '%', TITLE||' PET Result Statement '||TITLE;
          exec_stmt := LF||REPLACE(exec_stmt, quote_ident(temp_tname), DEBUG_TNAME);
          RAISE NOTICE '%', exec_stmt;
        END IF;   

      END IF;  -- IF (table_prefix = 'p') 

      -- =========================
      -- 9. Return the Result Set
      -- =========================
      exec_stmt := 'SELECT entity,'||LF||
                   'bytes,'||LF||
                   'pkts,'||LF||
                   'flows,'||LF||
                   'CASE WHEN bytes = 0 THEN 0 ELSE 100 * (bytes - retrans_bytes)/bytes::FLOAT END AS efficiency_pct,'||LF||
                   'CASE WHEN rtm_transactions = 0 THEN 0 ELSE rtm_total_delay/rtm_transactions::FLOAT END AS avg_total_delay,'||LF||
                   'CASE WHEN rtm_transactions = 0 THEN 0 ELSE rtm_server_delay/rtm_transactions::FLOAT END AS avg_server_delay,'||LF||
                   'rtm_transactions AS total_rtm_trans,'||LF||
                   'pet_server,'||LF||
                   'pet_client'||LF||
                   'FROM '||quote_ident(temp_tname)||LF||
                   'ORDER BY '||measure_type||' DESC, entity;';
      IF NOT is_debug THEN
        err_stmt := 'Couldn''t Get the Result Values.';
        FOR result IN EXECUTE exec_stmt
        LOOP
          RETURN NEXT result;
        END LOOP;
      ELSE
        RAISE NOTICE '% %', LF, 'Result Statement:';
        exec_stmt := LF||REPLACE (exec_stmt, quote_ident(temp_tname), DEBUG_TNAME);
        RAISE NOTICE '%', exec_stmt;
      END IF;   

      -- =================================================
      -- 10. Drop Temporary table and Restore environment
      -- =================================================
      IF NOT is_debug THEN
        exec_stmt := 'TRUNCATE TABLE '||quote_ident(temp_tname)||';';
        EXECUTE exec_stmt;
        exec_stmt := 'DROP TABLE '||quote_ident(temp_tname)||';';
        EXECUTE exec_stmt;
      END IF;

      -- EFFECTIVE_CACHE_SIZE
      exec_stmt := 'SET effective_cache_size = '||cache_size||';';   ---> restore value
      EXECUTE exec_stmt;

      -- ENABLE_NESTLOOP
      IF nestloop = 'on' THEN
        exec_stmt := 'SET enable_nestloop TO on;';
        EXECUTE exec_stmt;
      END IF;

/*
      -- ENABLE_HASHAGG
      IF hashagg = 'on' THEN
        exec_stmt := 'SET enable_hashagg TO on;';
        EXECUTE exec_stmt;
      END IF;

      -- ENABLE_HASHJOIN
      IF hashjoin = 'on' THEN
        exec_stmt := 'SET enable_hashjoin TO on;';
        EXECUTE exec_stmt;
      END IF;
*/

      -- Performance testing
      IF is_perf THEN
        UPDATE metrics.perfs 
          SET duration = (SELECT clock_timestamp() - p_beg_time)::INTERVAL
        WHERE perf_id = p_perf_id;
      END IF;

    ELSE
      RAISE EXCEPTION '%', 'Period is out of Range.';
    END IF;  -- IF is_prd_def

  ELSE
    RAISE EXCEPTION '%', 'End date couldn''t be less then Start date.';
  END IF;  -- IF (metrics.unix_timestamp(end_time)

  RETURN;

  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        err_stmt := err_stmt||LF||sqlerrm;
        RAISE EXCEPTION '[procedure "%"]: %', FUNCTION_NAME, err_stmt;
        RETURN;
      END;
END;
$body$
LANGUAGE 'plpgsql_sec'
VOLATILE
RETURNS NULL ON NULL INPUT 
EXTERNAL SECURITY DEFINER;

COMMENT ON FUNCTION get_top_n_flow_details 
(group_id INTEGER, site_id INTEGER, application_id INTEGER, class_id INTEGER, flow_type VARCHAR, measure_type VARCHAR, dim_value VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, table_prefix VARCHAR) 
IS 
'Get Detail Information for Top N Flows: Listeners, Talkers, DSCP, and VLAN for a given Device Group and Site.';

REVOKE ALL ON FUNCTION get_top_n_flow_details 
(group_id INTEGER, site_id INTEGER, application_id INTEGER, class_id INTEGER, flow_type VARCHAR, measure_type VARCHAR, dim_value VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, table_prefix VARCHAR) FROM PUBLIC;
ALTER FUNCTION get_top_n_flow_details 
(group_id INTEGER, site_id INTEGER, application_id INTEGER, class_id INTEGER, flow_type VARCHAR, measure_type VARCHAR, dim_value VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, table_prefix VARCHAR) OWNER TO metrics;
GRANT EXECUTE ON FUNCTION get_top_n_flow_details 
(group_id INTEGER, site_id INTEGER, application_id INTEGER, class_id INTEGER, flow_type VARCHAR, measure_type VARCHAR, dim_value VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, table_prefix VARCHAR) TO postgres;
GRANT EXECUTE ON FUNCTION get_top_n_flow_details 
(group_id INTEGER, site_id INTEGER, application_id INTEGER, class_id INTEGER, flow_type VARCHAR, measure_type VARCHAR, dim_value VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, table_prefix VARCHAR) TO rptuser;
