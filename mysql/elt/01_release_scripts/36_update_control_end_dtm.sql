/*
  Scipt
    36_update_control_end_dtm.sql
  Description:
    Update control_end_dtm value in control_downloads table.
    Update override_dtm value in src_tables table.
  Note:
    Should be executed before data download in DB3
  Restore:  
    UPDATE elt.control_downloads SET control_end_dtm = '2012-01-04 21:00:00' WHERE download_num = 195;
    UPDATE elt.src_tables SET override_dtm = NULL;
    COMMIT;
*/
SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
SET @@SESSION.SQL_MODE = '';

-- ====================================
-- 1. Get last_download_num
-- ====================================
SET @last_download_num = 0;
SET @last_finished_num = 0;

SELECT MAX(download_num)
  INTO @last_download_num 
  FROM elt.control_downloads;

SELECT MAX(download_num) 
  INTO @last_finished_num
  FROM elt.control_downloads
 WHERE download_status = 1
   AND append_status   = 1;

-- Display info about last download
SET @sql_stmt = IF(@last_download_num = 0 OR @last_finished_num = 0,
                   'SELECT "====> The first download should be done in STAGE tables" AS "Info:" FROM dual',
                   CONCAT('SELECT "====> The last_download_num = ', @last_download_num, '; last_finished_num = ', @last_finished_num, '" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 2. Remove last download (Just in case: interrupted ELT, not finished, error, ...)
-- ====================================
SET @err_num = 0;
SET @sql_stmt = IF(@last_download_num > @last_finished_num,
                   'CALL elt.remove_last_download (@err_num, FALSE)',
                   'SELECT "====> The last download has been finished successfully" AS "Info:" FROM dual'
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Message
SET @sql_stmt = IF(@last_download_num > @last_finished_num,
                   IF(@err_num = 0,
                      'SELECT "====> The last download has been removed" AS "Info:" FROM dual',
                      'SELECT "====> Could not remove last download..." AS "Error:" FROM dual'
                     ),
                   CONCAT('SELECT "====> Nothing to remove..." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 3. Update override_dtm = time before data population
-- Note: @last_download_num could be decreased by 1 -> use @last_finished_num
-- ====================================
SET @sql_stmt = IF(@last_finished_num > 0,
                   'UPDATE elt.src_tables SET override_dtm = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 SECOND)',
                   'SELECT "====> Table ''src_tables'' was not updated" AS "Info:" FROM dual'
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Display info
SET @sql_stmt = IF(@last_finished_num > 0,
                   'SELECT "====> Table ''src_tables'' has been updated" AS "Info:" FROM dual',
                   'SELECT "====> Table ''src_tables'': nothing to update" AS "Info:" FROM dual'
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 4. Update control_end_dtm = time before data population
-- Note: @last_download_num could be decreased by 1 -> use @last_finished_num
-- ====================================
SET @sql_stmt = IF(@last_finished_num > 0,
                   'UPDATE elt.control_downloads SET control_end_dtm = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 1 SECOND) WHERE download_num = @last_download_num',
                   'SELECT "====> Table ''control_downloads'' was not updated" AS "Info:" FROM dual'
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 
-- Display info
SET @sql_stmt = IF(@last_finished_num > 0,
                   'SELECT "====> Table ''control_downloads'' has been updated" AS "Info:" FROM dual',
                   'SELECT "====> Table ''control_downloads'': nothing to update" AS "Info:" FROM dual'
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

COMMIT;

SET @@SESSION.SQL_MODE = @old_sql_mode;
