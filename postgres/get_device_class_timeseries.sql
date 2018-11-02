-- ============================
-- get_device_class_timeseries ============================
-- ============================

CREATE OR REPLACE FUNCTION get_device_class_timeseries
(
  device_id   INTEGER,
  is_group    BOOLEAN,
  class_id    INTEGER,
  start_time  TIMESTAMPTZ,
  end_time    TIMESTAMPTZ
) 
RETURNS SETOF me.device_class_timeseries_type
AS
$body$
/*
  Description:
    Traffic Classes Reports. Level #3: Timeseries for Device/DeviceGroup and Traffic Class.
  Input:
    * Device ID or Device Group ID
    * Device Group Attribute: FALSE if Device, TRUE if Group 
    * Class ID
    * Start time(stamp) with time zone
    * End time(stamp) with time zone
  Output:
    * SETOF me.device_class_timeseries_type
  Example:
    SELECT * FROM me.get_device_class_timeseries (2, TRUE, 6, '2007-11-01 00:00:00-07', '2007-11-01 03:00:00-07');
  Result:
    +------------------------+------------+-----------+
    |       start_time       |  avg_rate  | peak_rate |
    +------------------------+------------+-----------+
    | 2007-11-01 00:00:00-07 |       0.00 |         0 |
    | 2007-11-01 01:00:00-07 |       0.00 |         0 |
    | 2007-11-01 02:00:00-07 |       0.00 |         0 |
    | 2007-11-01 03:00:00-07 |       0.00 |         0 |
    | 2007-11-01 04:00:00-07 |       0.00 |         0 |
    | 2007-11-01 05:00:00-07 |       0.00 |         0 |
    | 2007-11-01 06:00:00-07 |       0.00 |         0 |
    | 2007-11-01 07:00:00-07 |       0.00 |         0 |
    | 2007-11-01 08:00:00-07 |       0.00 |         0 |
    | 2007-11-01 09:00:00-07 |       0.00 |         0 |
    | 2007-11-01 10:00:00-07 |       0.00 |         0 |
    | 2007-11-01 11:00:00-07 |  173641.10 |   8723290 |
    | 2007-11-01 12:00:00-07 |  541400.00 |  37556248 |
    | 2007-11-01 13:00:00-07 |    6630.03 |    153483 |
    | 2007-11-01 14:00:00-07 |    6710.62 |    212329 |
    | 2007-11-01 15:00:00-07 |    8983.21 |    878894 |
    | 2007-11-01 16:00:00-07 | 2882190.48 |  70463457 |
    | 2007-11-01 17:00:00-07 | 5186339.84 |  70783668 |
    | 2007-11-01 18:00:00-07 |   73772.87 |  10548715 |
    | 2007-11-01 19:00:00-07 |       0.00 |         0 |
    | 2007-11-01 20:00:00-07 |       0.00 |         0 |
    | 2007-11-01 21:00:00-07 |       0.00 |         0 |
    | 2007-11-01 22:00:00-07 |       0.00 |         0 |
    | 2007-11-01 23:00:00-07 |       0.00 |         0 |
    | 2007-11-02 00:00:00-07 |       0.00 |         0 |
    +------------------------+------------+-----------+
*/
DECLARE
  -- Constants
  SCHEMA_NAME     CONSTANT CHAR(2)  := 'me';  -- Schema Name
  TABLE_PREFIX    CONSTANT CHAR(1)  := 'c';   -- Classes Table Prefix
  RAW_TNAME_LEN   CONSTANT SMALLINT := 13;
  LF              CONSTANT CHAR(1)  := CHR(10); 
  -- Variables
  is_prd_def      BOOLEAN := FALSE;
  period_stmt     TEXT;
  period_rec      metrics.table_periods_type%ROWTYPE;
  sql_stmt        TEXT;
  exec_stmt       TEXT = ''; -- !!!
  err_stmt        TEXT;
  result          me.device_class_timeseries_type%ROWTYPE;
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
    
    -- 2 -- Get the Measured Values
    err_stmt := 'Couldn''t Return the Result Set.';
    FOR period_rec IN EXECUTE period_stmt
    LOOP
      IF (period_rec.period_id > 0) THEN
        sql_stmt := 'SELECT '''||period_rec.start_time||''' AS start_time,'||LF;
      ELSE              
        sql_stmt := 'SELECT pt.datetime AS start_time,'||LF;
      END IF;              
      sql_stmt := sql_stmt|| 
                  'CASE WHEN SUM(pt.sample_interval_secs) = 0 THEN 0 ELSE 8*SUM(pt.bytes)/SUM(pt.sample_interval_secs) END AS avg_rate,'||LF||
                  'MAX(pt.peak_bps) AS peak_rate'||LF||
                  'FROM '||SCHEMA_NAME||'.'||period_rec.table_name||' pt'||LF||
                  'JOIN metrics.classes cl'||LF||
                  'ON pt.class_id = cl.class_id'||LF||
                  'AND cl.class_id = '||class_id||LF;
      -- Devices or Group of Devices
      IF is_group THEN
        sql_stmt := sql_stmt||
                    'JOIN metrics.group_devices gd'||LF||
                    'ON pt.device_id = gd.device_id'||LF|| 
                    'AND gd.group_id = '||device_id||LF;
      ELSE
        sql_stmt := sql_stmt||
                    'JOIN metrics.devices dv'||LF||
                    'ON pt.device_id = dv.device_id '||LF||
                    'AND dv.device_id = '||device_id||LF;
      END IF;

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

      sql_stmt := sql_stmt||'GROUP BY start_time'||LF;
      exec_stmt := exec_stmt||sql_stmt||'UNION'||LF;
    END LOOP; -- for all periods

    IF is_prd_def THEN
      exec_stmt := SUBSTR(exec_stmt, 1, CHAR_LENGTH(exec_stmt) - CHAR_LENGTH('UNION') - CHAR_LENGTH(LF));
      exec_stmt := exec_stmt||
                   'ORDER BY start_time;';
      IF is_debug THEN
        -- Check Statement
        RAISE NOTICE 'Statement:';
        RAISE NOTICE '%', exec_stmt;
      ELSE
        err_stmt  := 'Couldn''t Return the Result Set.';
        FOR result IN EXECUTE exec_stmt
        LOOP
          RETURN NEXT result;
        END LOOP;
      END IF;
      RETURN;
    ELSE
      err_stmt := 'Period is out of range.';
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
        RAISE EXCEPTION '[procedure "get_device_class_timeseries"]: %', err_stmt;
      END;
END;
$body$
LANGUAGE 'plpgsql_sec'
VOLATILE 
RETURNS NULL ON NULL INPUT 
EXTERNAL SECURITY DEFINER;

COMMENT ON FUNCTION get_device_class_timeseries 
(device_id INTEGER, is_group BOOLEAN, class_id INTEGER, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ) 
IS
'Get Timeseries for a given Device IP Address and Class ID.';

REVOKE ALL ON FUNCTION get_device_class_timeseries 
(device_id INTEGER, is_group BOOLEAN, class_id INTEGER, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ) FROM PUBLIC;
ALTER FUNCTION get_device_class_timeseries 
(device_id INTEGER, is_group BOOLEAN, class_id INTEGER, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ) OWNER TO metrics;
GRANT EXECUTE ON FUNCTION get_device_class_timeseries 
(device_id INTEGER, is_group BOOLEAN, class_id INTEGER, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ) TO postgres;
GRANT EXECUTE ON FUNCTION get_device_class_timeseries 
(device_id INTEGER, is_group BOOLEAN, class_id INTEGER, start_time TIMESTAMPTZ, end_time TIMESTAMPTZ) TO rptuser;
