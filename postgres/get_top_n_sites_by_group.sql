-- =========================
-- get_top_n_sites_by_group ===============================
-- =========================

CREATE OR REPLACE FUNCTION get_top_n_sites_by_group
(
  group_id      INTEGER,
  measure_type  VARCHAR, 
  start_time    TIMESTAMPTZ, 
  end_time      TIMESTAMPTZ, 
  row_nums      INTEGER
) 
RETURNS SETOF me.top_n_sites_type
AS
$body$
/*
  Description:
    Site Reports. Level #1: Top N values for Sites.
  Input:
    * Device Group Id
    * Measure Type. Values: 'bytes'|'pkts'
    * Start time(stamp) with time zone
    * End time(stamp) with time zone
    * Number of Rows in the Result Set (N)
  Output:
    * SETOF me.top_n_sites_type
  Example:
    SELECT * FROM me.get_top_n_sites_by_group (1, 'bytes',  '2008-11-17 17:00:00-08', '2008-11-17 18:00:00-08', 10);
  Result:
    +------------+---------+-------------+------------+---------+------------------+-----------+-----------+-----------------+
    |   total    | site_id |  site_name  |   bytes    |  pkts   | efficiency_level | avg_rate  | peak_rate | guar_rate_fails |
    +------------+---------+-------------+------------+---------+------------------+-----------+-----------+-----------------+
    | 4788454428 |       1 | coresitein  | 2245617437 | 3184693 |            99.84 | 238028.19 |   4987611 |               0 |
    | 4788454428 |       3 | siteinanna  | 1346524605 | 1792481 |            99.59 | 199485.13 |   3027491 |               0 |
    | 4788454428 |       2 | coresiteout | 1196312386 | 4491006 |            99.67 |  73918.31 |   4838345 |               0 |
    +------------+---------+-------------+------------+---------+------------------+-----------+-----------+-----------------+
*/
DECLARE
  -- Constants
  SCHEMA_NAME   CONSTANT CHAR(2)  := 'me';  -- Schema Name
  TABLE_PREFIX  CONSTANT CHAR(1)  := 'c';
  RAW_TNAME_LEN CONSTANT SMALLINT := 13;
  LF            CONSTANT CHAR(1)  := CHR(10); 
  -- Variables
  period_rec      metrics.table_periods_type%ROWTYPE;
  period_stmt     TEXT;
  is_prd_def      BOOLEAN := FALSE;
  total_rec       RECORD;
  sql_stmt        TEXT;
  exec_stmt       TEXT := ''; -- !!!
  join_site_stmt  TEXT; 
  join_class_stmt TEXT;
  join_group_stmt TEXT := '';
  err_stmt        TEXT;
  result          me.top_n_sites_type%ROWTYPE;
  is_debug        BOOLEAN := FALSE;  -- TRUE;
BEGIN
  IF (metrics.unix_timestamp(end_time) >= metrics.unix_timestamp(start_time)) THEN

    err_stmt := 'Couldn''t Get Set Of Periods.';
    period_stmt := 'SELECT table_name, period_id, period_name, start_time '||
                   'FROM metrics.get_set_of_periods ('||
                   quote_literal(SCHEMA_NAME)||', '||
                   quote_literal(start_time)||', '||
                   quote_literal(end_time)||', '||
                   quote_literal(TABLE_PREFIX)||', '||
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

    -- JOIN Sites (linked "pt")
    join_site_stmt := 'JOIN metrics.site_classes sc'||LF||
                      'ON pt.class_id = sc.class_id'||LF;

    -- JOIN Classes (linked "pt")
    join_class_stmt := 'JOIN metrics.classes cl'||LF||
                       'ON (pt.class_id = cl.class_id'||LF||
                       'AND cl.l_idx = cl.r_idx - 1)'||LF;

    -- JOIN Groups (linked "pt")
    IF group_id > 0 THEN
      join_group_stmt := 'JOIN metrics.dev_classes dc'||LF||
                         'ON (pt.class_id = dc.class_id'||LF||
                         'AND pt.device_id = dc.device_id)'||LF||
                         'JOIN metrics.group_devices gd'||LF||
                         'ON (gd.device_id = dc.device_id'||LF||
                         'AND gd.group_id = '||group_id||')'||LF;
    END IF;

    -- Get the Total Value for all Device Groups
    err_stmt := 'Couldn''t Get the Total Value of '||measure_type||' for all Device Groups.';
    exec_stmt := 'SELECT COALESCE(SUM(bt.b), 0) AS total '||LF||
                 'FROM (';
    -- For all periods
    FOR period_rec IN EXECUTE period_stmt
    LOOP
      -- Check of the Particular Period
      IF (CHAR_LENGTH(period_rec.table_name) > 1) THEN
        is_prd_def := TRUE;
        sql_stmt := 'SELECT SUM(pt.'||measure_type||') AS b'||LF||
                    'FROM '||SCHEMA_NAME||'.'||period_rec.table_name||' pt'||LF||
                    join_site_stmt||
                    join_class_stmt||
                    join_group_stmt;
        -- Period
        IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
          -- Rollup table
          IF period_rec.period_id > 0 THEN
            sql_stmt := sql_stmt||
                        'WHERE pt.period_id = '||period_rec.period_id||LF;
          ELSE
            sql_stmt := sql_stmt||
                        'WHERE pt.period_id > 0'||LF;
          END IF;
        END IF;
        exec_stmt := exec_stmt||sql_stmt||'UNION'||LF;
      END IF;
    END LOOP;

    IF is_prd_def THEN
      exec_stmt := SUBSTR(exec_stmt, 1, CHAR_LENGTH(exec_stmt) - CHAR_LENGTH('UNION') - CHAR_LENGTH(LF));
      exec_stmt := exec_stmt||
                   ') bt;';
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
                 'res.site_id AS site_id,'||LF||
                 'LTRIM(res.site_name) AS site_name,'||LF||
                 'SUM(res.bytes) AS bytes,'||LF||
                 'SUM(res.pkts) AS pkts,'||LF||
                 'AVG(res.efficiency_level) AS efficiency_level,'||LF||
                 'AVG(res.avg_rate) AS avg_rate,'||LF||
                 'MAX(res.peak_rate) AS peak_rate,'||LF||
                 'SUM(res.guar_rate_fails) AS guar_rate_fails'||LF|| 
                 'FROM ('||LF;
    FOR period_rec IN EXECUTE period_stmt
    LOOP
      sql_stmt := 'SELECT st.site_id AS site_id,'||LF||
                  'st.name AS site_name,'||LF||
                  'SUM(pt.bytes) AS bytes,'||LF||
                  'SUM(pt.pkts) AS pkts,'||LF||
                  'CASE WHEN SUM(pt.bytes) = 0 THEN 0 ELSE 100 * (SUM(pt.bytes) - SUM(pt.tcp_retx_bytes)) / SUM(pt.bytes) END AS efficiency_level,'||LF||
                  'CASE WHEN SUM(pt.sample_interval_secs) = 0 THEN 0 ELSE 8 * SUM(pt.bytes) / SUM(pt.sample_interval_secs) END AS avg_rate,'||LF||
                  'MAX(pt.peak_bps) AS peak_rate,'||LF||
                  'SUM(pt.guar_rate_fails) AS guar_rate_fails'||LF|| 
                  'FROM '||SCHEMA_NAME||'.'||period_rec.table_name||' pt'||LF||
                  join_site_stmt||
                  'JOIN metrics.sites st'||LF||
                  'ON sc.site_id = st.site_id'||LF||
                  join_class_stmt||
                  join_group_stmt;
      -- Period
      IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
        -- Rollup table
        IF (period_rec.period_id > 0) THEN
          sql_stmt := sql_stmt || 'WHERE pt.period_id = '||period_rec.period_id||LF;
        ELSE
          -- the whole table
          sql_stmt := sql_stmt || 'WHERE pt.period_id > 0'||LF;
        END IF;  
      END IF;
      sql_stmt := sql_stmt||
                  'GROUP BY st.site_id, st.name'||LF;
      exec_stmt := exec_stmt||sql_stmt||'UNION'||LF;
    END LOOP;

    IF is_prd_def THEN
      exec_stmt := SUBSTR(exec_stmt, 1, CHAR_LENGTH(exec_stmt) - CHAR_LENGTH('UNION') - CHAR_LENGTH(LF));
      exec_stmt := exec_stmt||
                   ') res'||LF||
                   'GROUP BY res.site_id, res.site_name'||LF||
                   'HAVING SUM(res.'||measure_type||') > 0'||LF||
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
        RAISE EXCEPTION '[procedure "get_top_n_sites_by_group"]: %', err_stmt;
        RETURN;
      END;
END;
$body$
LANGUAGE 'plpgsql_sec'
VOLATILE
RETURNS NULL ON NULL INPUT 
EXTERNAL SECURITY DEFINER;

COMMENT ON FUNCTION get_top_n_sites_by_group 
(group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) 
IS 
'Get Result Set for Top N Sites (Group of Classes).';

REVOKE ALL ON FUNCTION get_top_n_sites_by_group 
(group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) FROM PUBLIC;
ALTER FUNCTION get_top_n_sites_by_group 
(group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) OWNER TO metrics;
GRANT EXECUTE ON FUNCTION get_top_n_sites_by_group 
(group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) TO postgres;
GRANT EXECUTE ON FUNCTION get_top_n_sites_by_group 
(group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) TO rptuser;
