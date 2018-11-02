-- ====================================
-- get_top_n_sites_by_group_timeseries =====================
-- ====================================

CREATE OR REPLACE FUNCTION get_top_n_sites_by_group_timeseries
(
  group_id      INTEGER,
  measure_type  VARCHAR, 
  start_time    TIMESTAMPTZ, 
  end_time      TIMESTAMPTZ, 
  row_nums      INTEGER
) 
RETURNS SETOF me.top_n_sites_timeseries_type
AS
$body$
/*
  Input:
    * Device Group Id
    * Measure Type. Values: 'bytes'|'pkts'
    * Start time(stamp) with time zone
    * End time(stamp) with time zone
    * Number of Sites in the Result Set (N)
  Output:
    * SETOF me.top_n_sites_timeseries_type
  Example:
    SELECT * FROM me.get_top_n_sites_by_group_timeseries (1, 'bytes',  '2008-06-15 10:00:00-07', '2008-06-15 11:00:00-07', 10);
  Result:
    +---------+---------+-----------+------------------------+----------+
    | ord_num | site_id | site_name |       start_time       | avg_rate |
    +---------+---------+-----------+------------------------+----------+
    |       1 |     136 | Telnet    | 2008-06-15 10:00:00-07 |  7925.92 |
    |       1 |     136 | Telnet    | 2008-06-15 10:15:00-07 |  4351.24 |
    |       1 |     136 | Telnet    | 2008-06-15 10:30:00-07 | 10148.76 |
    |       1 |     136 | Telnet    | 2008-06-15 10:45:00-07 |  6830.57 |
    |       2 |      49 | SSH       | 2008-06-15 10:00:00-07 |  4187.79 |
    |       2 |      49 | SSH       | 2008-06-15 10:15:00-07 |  8251.41 |
    |       2 |      49 | SSH       | 2008-06-15 10:30:00-07 |  4942.52 |
    |       2 |      49 | SSH       | 2008-06-15 10:45:00-07 | 10120.87 |
    |       3 |     133 | SMTP      | 2008-06-15 10:00:00-07 | 12412.18 |
    |       3 |     133 | SMTP      | 2008-06-15 10:15:00-07 |  9211.61 |
    |       3 |     133 | SMTP      | 2008-06-15 10:30:00-07 | 14350.92 |
    |       3 |     133 | SMTP      | 2008-06-15 10:45:00-07 | 20322.98 |
    |       4 |     129 | rlogin    | 2008-06-15 10:00:00-07 | 19336.62 |
    |       4 |     129 | rlogin    | 2008-06-15 10:15:00-07 |  9837.25 |
    |       4 |     129 | rlogin    | 2008-06-15 10:30:00-07 | 19728.78 |
    |       4 |     129 | rlogin    | 2008-06-15 10:45:00-07 |  9253.18 |
    |       5 |      10 | HTTP      | 2008-06-15 10:00:00-07 |  1376.42 |
    |       5 |      10 | HTTP      | 2008-06-15 10:15:00-07 |  1171.69 |
    |       5 |      10 | HTTP      | 2008-06-15 10:30:00-07 |  1232.10 |
    |       5 |      10 | HTTP      | 2008-06-15 10:45:00-07 |   698.97 |
    |       6 |       2 | Site #2   | 2008-06-15 10:00:00-07 |   395.31 |
    |       6 |       2 | Site #2   | 2008-06-15 10:15:00-07 |   340.18 |
    |       6 |       2 | Site #2   | 2008-06-15 10:30:00-07 |   468.39 |
    |       6 |       2 | Site #2   | 2008-06-15 10:45:00-07 |   265.52 |
    |       7 |      68 | NTP       | 2008-06-15 10:00:00-07 |     7.40 |
    |       7 |      68 | NTP       | 2008-06-15 10:15:00-07 |    11.78 |
    |       7 |      68 | NTP       | 2008-06-15 10:30:00-07 |    12.48 |
    |       7 |      68 | NTP       | 2008-06-15 10:45:00-07 |    11.79 |
    |       8 |      82 | Citrix    | 2008-06-15 10:00:00-07 |     4.16 |
    |       8 |      82 | Citrix    | 2008-06-15 10:15:00-07 |     0.00 |
    |       8 |      82 | Citrix    | 2008-06-15 10:30:00-07 |     0.00 |
    |       8 |      82 | Citrix    | 2008-06-15 10:45:00-07 |     0.00 |
    +---------+---------+-----------+------------------------+----------+
*/
DECLARE
  -- Constants
  SCHEMA_NAME     CONSTANT CHAR(2)  := 'me';  -- Schema Name
  TABLE_PREFIX    CONSTANT CHAR(1)  := 'c';   -- Table Prefix
  RAW_TNAME_LEN   CONSTANT SMALLINT := 13;
  LF              CONSTANT CHAR(1)  := CHR(10); 
  -- Variables
  period_stmt     TEXT;
  period_rec      metrics.table_periods_type%ROWTYPE;
  is_prd_def      BOOLEAN := FALSE;
  ord_num         INTEGER := 0; 
  site_stmt       TEXT;
  join_site_stmt  TEXT; 
  join_class_stmt TEXT;
  join_group_stmt TEXT := '';
  site_rec        RECORD;   
  sql_stmt        TEXT;
  exec_stmt       TEXT = ''; -- !!!
  err_stmt        TEXT;
  result          me.top_n_sites_timeseries_type%ROWTYPE;
  is_debug        BOOLEAN := FALSE; -- TRUE; -- FALSE;
BEGIN
  IF (metrics.unix_timestamp(end_time) >= metrics.unix_timestamp(start_time)) THEN

    -- 1 -- Get Time Periods
    err_stmt := 'Couldn''t Get Set Of Periods.';
    period_stmt := 'SELECT table_name, period_id, period_name, start_time '||
                   'FROM metrics.get_set_of_periods ('||
                   quote_literal(SCHEMA_NAME)||', '||
                   quote_literal(start_time)||', '||
                   quote_literal(end_time)||', '||
                   quote_literal(TABLE_PREFIX)||', '||
                   'TRUE)';  -- all periods
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
    
    -- Prepare JOIN SITES statement (for "pt" table)
    join_site_stmt := 'JOIN metrics.site_classes sc'||LF||
                      'ON pt.class_id = sc.class_id'||LF||
                      'JOIN metrics.sites st'||LF||
                      'ON st.site_id = sc.site_id'||LF;
  
    -- Prepare JOIN CLASSES statement (for "pt" table)
    join_class_stmt := 'JOIN metrics.classes cl'||LF||
                       'ON (pt.class_id = cl.class_id'||LF||
                       'AND cl.l_idx = cl.r_idx - 1)'||LF;
  
    -- Prepare JOIN GROUPS statement (for "pt" table)
    IF group_id > 0 THEN
      join_group_stmt := 'JOIN metrics.dev_classes dc'||LF||
                         'ON (pt.class_id = dc.class_id'||LF||
                         'AND pt.device_id = dc.device_id)'||LF||
                         'JOIN metrics.group_devices gd'||LF||
                         'ON (gd.device_id = dc.device_id'||LF||
                         'AND gd.group_id = '||group_id||')'||LF;
    END IF;

    -- 2 -- Get Set of Top N Sites for a given Period and measured type
    err_stmt   := 'Couldn''t Get of the Top N Sites.';
    site_stmt := 'SELECT res.site_id AS site_id,'||LF||
                 'SUM(res.'||measure_type||') AS '||measure_type||LF||
                 'FROM ('||LF;

    FOR period_rec IN EXECUTE period_stmt
    LOOP
      -- Check of the particular Period
      IF (CHAR_LENGTH(period_rec.table_name) > 1) THEN
        is_prd_def := TRUE;
        sql_stmt := 'SELECT st.site_id AS site_id,'||LF||
                    'SUM(pt.'||measure_type||') AS '||measure_type||LF||
                    'FROM '||SCHEMA_NAME||'.'||period_rec.table_name||' pt'||LF||
                    join_site_stmt||
                    join_class_stmt||
                    join_group_stmt;
        -- Period
        IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
          -- Rollup table
          IF (period_rec.period_id > 0) THEN
            sql_stmt := sql_stmt||
                        'WHERE pt.period_id = '||period_rec.period_id||LF;
          ELSE
            sql_stmt := sql_stmt||
                        'WHERE pt.period_id > 0'||LF;
          END IF;
        END IF;
        sql_stmt := sql_stmt||'GROUP BY st.site_id'||LF;
        site_stmt := site_stmt||sql_stmt||'UNION'||LF;
      END IF;
    END LOOP;

    IF is_prd_def THEN
      site_stmt := SUBSTR(site_stmt, 1, CHAR_LENGTH(site_stmt) - CHAR_LENGTH('UNION') - CHAR_LENGTH(LF));
      site_stmt := site_stmt ||') res'||LF||
                   'GROUP BY res.site_id'||LF||
                   'HAVING SUM(res.'||measure_type||') > 0'||LF||
                   'ORDER BY '||measure_type||' DESC'||LF||
                   'LIMIT '||row_nums||';';
    ELSE
      err_stmt := 'Period is out of Range.';
      RAISE EXCEPTION '';
    END IF;

    IF is_debug THEN
      -- Check Statement
      RAISE NOTICE 'Statement:';
      RAISE NOTICE '%', site_stmt;
      -- Check Sites
      RAISE NOTICE 'Sites:';
      FOR site_rec IN EXECUTE site_stmt
      LOOP
        RAISE NOTICE '%', site_rec.site_id;
      END LOOP;
    END IF;   

    -- 3 -- Get Set of Values for Top N Sites and for a given Period
    err_stmt  := 'Couldn''t Return the Result Set.';
    -- for all Top N Classes
    FOR site_rec IN EXECUTE site_stmt
    LOOP
      ord_num := ord_num + 1;
      -- for all Periods
      FOR period_rec IN EXECUTE period_stmt
      LOOP
        sql_stmt := 'SELECT '||ord_num||' AS ord_num,'||LF||
                    'st.site_id AS site_id,'||LF||
                    'LTRIM(st.name) AS site_name,'||LF;
        IF (period_rec.period_id > 0) THEN
          sql_stmt := sql_stmt ||''''||period_rec.start_time||''' AS start_time,'||LF;
        ELSE              
          -- sql_stmt := sql_stmt || 'metrics.get_timestamp_from_tname('||quote_literal(SCHEMA_NAME)||','||quote_literal(period_rec.table_name)||') AS start_time,'||LF;
          sql_stmt := sql_stmt || 'pt.datetime AS start_time,'||LF;
        END IF;              
        sql_stmt := sql_stmt || 'CASE WHEN SUM(pt.sample_interval_secs) = 0 THEN 0 ELSE 8*SUM(pt.bytes)/SUM(pt.sample_interval_secs) END AS avg_rate'||LF||
                    'FROM '||SCHEMA_NAME||'.'||period_rec.table_name||' pt'||LF||
                    join_site_stmt||
                    'AND st.site_id = '||site_rec.site_id||LF||
                    join_class_stmt||
                    join_group_stmt;
        -- Period
        IF CHAR_LENGTH(period_rec.table_name) < RAW_TNAME_LEN THEN
          -- Rollup table
          IF (period_rec.period_id > 0) THEN
            sql_stmt := sql_stmt||
                        'WHERE pt.period_id = '||period_rec.period_id||LF;
          ELSE
            sql_stmt := sql_stmt||
                        'WHERE pt.period_id > 0'||LF;
          END IF;  
        END IF;
        sql_stmt := sql_stmt||
                    'GROUP BY st.site_id, LTRIM(st.name), start_time'||LF;
        exec_stmt := exec_stmt||sql_stmt||'UNION'||LF;
      END LOOP; -- for Periods
    END LOOP; -- for Top N classes

    IF is_prd_def THEN
      -- If period exists
      IF (site_rec.site_id > 0) THEN
        -- If application has been defined => exec_stmt <> ''
        exec_stmt := SUBSTR(exec_stmt, 1, CHAR_LENGTH(exec_stmt) - CHAR_LENGTH('UNION') - CHAR_LENGTH(LF));
        exec_stmt := exec_stmt||
                     'ORDER BY ord_num, start_time;';
        IF is_debug THEN
          -- Check the Statement
          exec_stmt := 'Result Statement:'||LF||exec_stmt;
          RAISE NOTICE '%', exec_stmt;
        ELSE
          err_stmt  := 'Couldn''t Return the Result Set.';
          FOR result IN EXECUTE exec_stmt
          LOOP
            RETURN NEXT result;
          END LOOP;
        END IF;
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
        RAISE EXCEPTION '[procedure "get_top_n_sites_by_group_timeseries"]: %', err_stmt;
      END;
END;
$body$
LANGUAGE 'plpgsql_sec'
VOLATILE 
RETURNS NULL ON NULL INPUT 
EXTERNAL SECURITY DEFINER;

COMMENT ON FUNCTION get_top_n_sites_by_group_timeseries 
(group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) 
IS 
'Get Top N Site Timeseries for a given Device Group.';

REVOKE ALL ON FUNCTION get_top_n_sites_by_group_timeseries 
(group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) FROM PUBLIC;
ALTER FUNCTION get_top_n_sites_by_group_timeseries 
(group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) OWNER TO metrics;
GRANT EXECUTE ON FUNCTION get_top_n_sites_by_group_timeseries 
(group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) TO postgres;
GRANT EXECUTE ON FUNCTION get_top_n_sites_by_group_timeseries 
(group_id INTEGER, measure_type VARCHAR, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ, row_nums INTEGER) TO rptuser;
