-- ================================
-- get_top_n_child_traffic_classes ===================================
-- ================================

CREATE OR REPLACE FUNCTION get_top_n_child_traffic_classes
(
  prnt_class_path  VARCHAR,
  group_id         INTEGER,
  measure_type     VARCHAR,
  start_time       TIMESTAMPTZ,
  end_time         TIMESTAMPTZ,
  row_nums         INTEGER
)
RETURNS SETOF me.top_n_child_traffic_classes_type
AS
$body$
/*
  Description:
    Traffic Classes Reports. Level #1: Top N values for Immediate Children (Child Classes).
  Input:
    * Parent Class Path.
    * Group Id.
    * Measure Type. Values: 'bytes'|'pkts'
    * Start time(stamp) with time zone
    * End time(stamp) with time zone
    * Number of Rows in the Result Set (N)
  Output:
    * SETOF me.top_n_child_traffic_classes_type
    TYPE me.top_n_child_traffic_classes_type
    (
      total            BIGINT,
      class_id         INTEGER,
      class_name       VARCHAR,
      bytes            BIGINT,
      pkts             BIGINT,
      efficiency_level NUMERIC(5,2),
      part_size        BIGINT,
      part_utilization NUMERIC(14,2),
      avg_rate         NUMERIC(14,2),
      peak_rate        BIGINT
    );
  Example:
    SELECT * FROM me.get_top_n_child_traffic_classes ('/Inbound', 1, 'bytes', '2008-11-20 14:00:00-08', '2008-11-20 15:00:00-08', 10);
  Result:
*/
DECLARE
  -- Constants
  SCHEMA_NAME        CONSTANT CHAR(2)  := 'me';  -- Schema Name
  CLASS_TABLE_PREFIX CONSTANT CHAR(1)  := 'c';   -- Classes Table Prefix
  PART_TABLE_PREFIX  CONSTANT CHAR(1)  := 'p';   -- Partitions Table Prefix 
  RAW_TNAME_LEN      CONSTANT SMALLINT := 13;
  LF                 CONSTANT CHAR(1)  := CHR(10); 
  -- Variables
  period_rec    metrics.table_periods_type%ROWTYPE;
  period_stmt   TEXT;
  part_tbl_name VARCHAR;
  prnt_class_id INTEGER;
  is_prd_def    BOOLEAN := FALSE;
  total_rec     RECORD;
  sql_stmt      TEXT;
  exec_stmt     TEXT = ''; -- !!!
  err_stmt      TEXT;
  result        me.top_n_child_traffic_classes_type%ROWTYPE;
  is_debug      BOOLEAN := FALSE;  -- TRUE;
BEGIN
  IF (metrics.unix_timestamp(end_time) >= metrics.unix_timestamp(start_time)) THEN

    err_stmt := 'Couldn''t Get Set Of Periods.';
    period_stmt := 'SELECT table_name, period_id, period_name, start_time '||
                   'FROM metrics.get_set_of_periods ('||
                   quote_literal(SCHEMA_NAME)||', '||
                   quote_literal(start_time)||', '||
                   quote_literal(end_time)||', '||
                   quote_literal(CLASS_TABLE_PREFIX)||', '||
                   'FALSE)';  -- optimization
    -- Check the set of periods
    FOR period_rec IN EXECUTE period_stmt 
    LOOP
      IF CHAR_LENGTH(period_rec.table_name) > 1 THEN
        is_prd_def := TRUE;
        EXIT;  
      ELSE
        -- Exception if period is undefined 
        RAISE EXCEPTION '';
      END IF;  
    END LOOP;

    IF is_debug THEN
      -- Check Periods
      RAISE NOTICE 'Periods:';
      FOR period_rec IN EXECUTE period_stmt
      LOOP
        RAISE NOTICE '% | % | % | %', period_rec.table_name, period_rec.period_id, period_rec.period_name, period_rec.start_time;
      END LOOP;
    END IF;  
    
    -- Get Parent Class ID
    SELECT class_id FROM metrics.classes WHERE path = prnt_class_path::TEXT INTO prnt_class_id;
    IF prnt_class_id IS NULL THEN
      -- Exception if period is undefined 
      -- err_stmt := 'Undefined Class Name = "'||prnt_class_path||'"';
      -- RAISE EXCEPTION '';
      RETURN;
    END IF;
    
    -- Get the Total Value
    err_stmt := 'Couldn''t Get the Total Value for '||measure_type||'.';
    exec_stmt := 'SELECT COALESCE(SUM(bt.b), 0) AS total FROM (';
    -- For all periods
    FOR period_rec IN EXECUTE period_stmt
    LOOP
      -- Check the current Period
      IF (CHAR_LENGTH(period_rec.table_name) > 1) THEN
        is_prd_def := TRUE;
        sql_stmt := 'SELECT SUM(pt.'||measure_type||') AS b'||LF||
                    'FROM '||SCHEMA_NAME||'.'||period_rec.table_name||' pt '||LF||
                    'JOIN metrics.classes cl'||LF||
                    'ON cl.class_id = pt.class_id'||LF||
                    'JOIN metrics.group_devices gd'||LF||
                    'ON (pt.device_id = gd.device_id'||LF||
                    'AND gd.group_id = '||group_id||')'||LF||
                    'WHERE cl.parent_id = '||prnt_class_id||LF;
        -- Period
        IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
          -- Rollup table
          IF period_rec.period_id > 0 THEN
            sql_stmt := sql_stmt||
                        'AND pt.period_id = '||period_rec.period_id||LF;
          ELSE
            sql_stmt := sql_stmt||
                        'AND pt.period_id > 0'||LF;
          END IF;
        END IF;
        exec_stmt := exec_stmt||sql_stmt||'UNION'||LF;
      END IF;
    END LOOP;

    IF is_prd_def THEN
      exec_stmt := SUBSTR(exec_stmt, 1, CHAR_LENGTH(exec_stmt) - CHAR_LENGTH('UNION') - CHAR_LENGTH(LF));
      exec_stmt := exec_stmt ||') AS bt;';
      IF is_debug THEN
        RAISE NOTICE 'Total:';
        RAISE NOTICE '%', exec_stmt;
      END IF;   
      -- Get the Total Value
      FOR total_rec IN EXECUTE exec_stmt LOOP
      END LOOP;
    ELSE  
      err_stmt := 'Period is out of Range.';
      RAISE EXCEPTION '';
    END IF;
    
    -- Get the Measured values
    err_stmt := 'Couldn''t Get the Result Set.';
    exec_stmt := 'SELECT '||total_rec.total||' AS total,'||LF||
                 'res.class_id AS class_id,'||LF||
                 'res.class_name AS class_name,'||LF||
                 'SUM(res.bytes) AS bytes,'||LF||
                 'SUM(res.pkts) AS pkts,'||LF||
                 'AVG(res.efficiency_level) AS efficiency_level,'||LF||
                 'COALESCE(SUM(res.part_size), 0) AS part_size,'||LF||
                 'COALESCE(AVG(res.part_utilization), 0) AS part_utilization,'||LF||
                 'AVG(res.avg_rate) AS avg_rate,'||LF||
                 'MAX(res.peak_rate) AS peak_rate'||LF||
                 'FROM ('||LF;
    FOR period_rec IN EXECUTE period_stmt
    LOOP
      part_tbl_name := PART_TABLE_PREFIX||SUBSTR(period_rec.table_name, 2, LENGTH(period_rec.table_name) - 1);
      sql_stmt := 'SELECT cl.class_id AS class_id,'||LF||
                  'cl.name AS class_name,'||LF||
                  'SUM(pt.bytes) AS bytes,'||LF||
                  'SUM(pt.pkts) AS pkts,'||LF||
                  'CASE WHEN SUM(pt.bytes) = 0 THEN 0 ELSE 100 * (SUM(pt.bytes) - SUM(pt.tcp_retx_bytes)) / SUM(pt.bytes) END AS efficiency_level,'||LF||
                  'SUM(pr.part_size_bps) AS part_size,'||LF||
                  'CASE WHEN SUM(pr.part_size_bps) = 0 THEN 0 ELSE 8 * SUM(pr.bytes) / SUM(pr.part_size_bps) END AS part_utilization,'||LF||
                  'CASE WHEN SUM(pt.sample_interval_secs) = 0 THEN 0 ELSE 8 * SUM(pt.bytes) / SUM(pt.sample_interval_secs) END AS avg_rate,'||LF||
                  'MAX(pt.peak_bps) AS peak_rate'||LF||
                  'FROM '||SCHEMA_NAME||'.'||period_rec.table_name||' pt '||LF||
                  'JOIN metrics.classes cl'||LF||
                  'ON pt.class_id = cl.class_id'||LF||
                  'AND cl.parent_id = '||prnt_class_id||LF||
                  'JOIN metrics.group_devices gd'||LF||
                  'ON (pt.device_id = gd.device_id'||LF||
                  'AND gd.group_id = '||group_id||')'||LF||
                  'LEFT JOIN '||SCHEMA_NAME||'.'||part_tbl_name||' pr'||LF||
                  'ON pr.device_id = pt.device_id'||LF;
      IF CHAR_LENGTH(part_tbl_name) < RAW_TNAME_LEN THEN
        sql_stmt := sql_stmt||
                    'AND pr.period_id = pt.period_id'||LF;   -- Rollup table
      END IF;          
      sql_stmt := sql_stmt||
                  'AND cl.path = (SELECT path FROM metrics.partitions mp WHERE mp.part_id = pr.part_id)'||LF;
      -- Period
      IF CHAR_LENGTH(part_tbl_name) < RAW_TNAME_LEN THEN
        -- if not RAW table
        IF (period_rec.period_id > 0) THEN
          sql_stmt := sql_stmt||
                      'WHERE pt.period_id = '||period_rec.period_id||LF;
        ELSE
          sql_stmt := sql_stmt||
                      'WHERE pt.period_id > 0'||LF;
        END IF;  
      END IF;  
      sql_stmt := sql_stmt||
                  'GROUP BY cl.class_id, cl.name'||LF;
      exec_stmt := exec_stmt||sql_stmt||'UNION'||LF;
    END LOOP;

    IF is_prd_def THEN
      exec_stmt := SUBSTR(exec_stmt, 1, CHAR_LENGTH(exec_stmt) - CHAR_LENGTH('UNION') - CHAR_LENGTH(LF));
      exec_stmt := exec_stmt ||') AS res '||LF||
                   'GROUP BY res.class_id, res.class_name'||LF||
                   'ORDER BY '||measure_type||' DESC'||LF||
                   'LIMIT '||row_nums||';';
      -- Return the Result Set
      IF is_debug THEN
        -- Check the Statement
        exec_stmt := 'Result Statement:'||LF||exec_stmt;
        RAISE NOTICE '%', exec_stmt;
      ELSE  
        err_stmt := 'Couldn''t Return the Result Set.';
        FOR result IN EXECUTE exec_stmt
        LOOP
          RETURN NEXT result;
        END LOOP;
      END IF;   
      RETURN;
    ELSE
      err_stmt := 'Period is out of Range.';
      RAISE EXCEPTION '';
    END IF;  
  ELSE
    err_stmt := 'End date couldn''t be less then Start date.';
    RAISE EXCEPTION '';
  END IF;

  EXCEPTION
    WHEN OTHERS THEN
      BEGIN
        err_stmt := err_stmt||LF||sqlerrm;
        RAISE EXCEPTION '[procedure "get_top_n_child_traffic_classes"]: %', err_stmt;
        RETURN;
      END;
END;
$body$
LANGUAGE 'plpgsql_sec'
VOLATILE
RETURNS NULL ON NULL INPUT 
EXTERNAL SECURITY DEFINER;

COMMENT ON FUNCTION get_top_n_child_traffic_classes 
(prnt_class_path VARCHAR, group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) 
IS
'Get Top N values for Immediate Child Classes.';

REVOKE ALL ON FUNCTION get_top_n_child_traffic_classes 
(prnt_class_path VARCHAR, group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) FROM PUBLIC;
ALTER FUNCTION get_top_n_child_traffic_classes 
(prnt_class_path VARCHAR, group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) OWNER TO metrics;
GRANT EXECUTE ON FUNCTION get_top_n_child_traffic_classes 
(prnt_class_path VARCHAR, group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) TO postgres;
GRANT EXECUTE ON FUNCTION get_top_n_child_traffic_classes 
(prnt_class_path VARCHAR, group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) TO rptuser;