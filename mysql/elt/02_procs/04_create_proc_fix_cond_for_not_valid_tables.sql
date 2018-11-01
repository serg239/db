/*
  Version:
    2011.11.12.01
  Script:
    04_create_proc_fix_cond_for_not_valid_tables.sql
  Description:
    Fix conditions for table which are not valid for migration:
    - if "There is no PK on Master table"         -> proc_block_size = 0  (no blocks)
    - if "There is no column for data processing" -> proc_block_size = -1 (copy entire table)
  Input:
    debug_mode      - Debug Mode.
                      Values:
                        * FALSE (0) - execute SQL statements
                        * TRUE  (1) - show SQL statements
  Output:
    * error_code: 
      * 0   - Success
      * < 0 - Error 
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\04_create_proc_fix_cond_for_not_valid_tables.sql
  Usage:  
    CALL elt.fix_cond_for_not_valid_tables (@err, FALSE);  -- execute
*/
DELIMITER $$ 

DROP PROCEDURE IF EXISTS elt.fix_cond_for_not_valid_tables$$

CREATE PROCEDURE elt.fix_cond_for_not_valid_tables
(
 OUT error_code_out  INTEGER,
  IN debug_mode_in   BOOLEAN      -- JIC
) 
BEGIN

  DECLARE NO_PK_ON_TABLE   VARCHAR(128) DEFAULT 'There is no PK on Master table';
  DECLARE NO_DTM_COLUMN    VARCHAR(128) DEFAULT 'There is no column for data processing';
  DECLARE NO_FK_TO_MASTER  VARCHAR(128) DEFAULT 'There is no FK to Master table';

  SET @old_sql_mode = (SELECT @@SESSION.SQL_MODE);
  SET @@SESSION.SQL_MODE = '';

  SET error_code_out = -2; 
  
  -- Rule #1: if "There is no PK on Master table" -> proc_block_size = 0  (insert without blocks)
  SET @cond_str = CONCAT('%', NO_PK_ON_TABLE, '%');

  UPDATE elt.src_tables
     SET proc_block_size        = 0,  -- No blocks
         src_table_valid_status = 1,  -- became valid
         modified_by            = SUBSTRING_INDEX(USER(), '@', 1),
         modified_at            = CURRENT_TIMESTAMP()
   WHERE comments LIKE @cond_str;
  COMMIT;

  -- Rule #2 (Attn: !!! after Rule #1 !!!):
  -- More strong condition --
  -- if "There is no column for data processing" -> proc_block_size = -1 (delete/insert entire table in STAGE and DELTA)
  -- SET @cond_str = CONCAT('%', NO_DTM_COLUMN, '%');

  UPDATE elt.src_tables
     SET proc_block_size        = -1,  -- Migrate the whole table
         src_table_valid_status = 1,   -- became valid
         modified_by            = SUBSTRING_INDEX(USER(), '@', 1),
         modified_at            = CURRENT_TIMESTAMP()
   WHERE dtm_column_name IS NULL;
  COMMIT;

  -- Bug - use account_id instead of external_account_id
  UPDATE elt.src_tables
     SET sharding_column_name = NULL,
         modified_by          = SUBSTRING_INDEX(USER(), '@', 1),
         modified_at          = CURRENT_TIMESTAMP()
   WHERE host_alias      = 'db2' 
     AND src_schema_name = 'external_content'
     AND src_table_name IN ('external_attribute', 'external_item');
  COMMIT;
  SET error_code_out = 0;
  -- restore MySQL SQL Mode 
  SET @@SESSION.SQL_MODE = @old_sql_mode;
END$$

DELIMITER ;

SELECT '====> Procedure ''fix_cond_for_not_valid_tables'' has been created' AS "Info:" FROM dual;
