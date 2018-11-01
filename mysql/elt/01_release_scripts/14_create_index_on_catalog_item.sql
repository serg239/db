SET SQL_MODE = '';
    
SET @SCHEMA_NAME = 'catalog';
SET @TABLE_NAME  = 'item';
SET @INDEX_NAME  = 'r_item_content_item_content_item';
SET @COLUMN_NAME = 'content_item_id';

SET @v_index_exists = NULL;
    
SELECT COUNT(*) 
  INTO @v_index_exists
  FROM information_schema.statistics
 WHERE table_schema = @SCHEMA_NAME
   AND table_name   = @TABLE_NAME
   AND index_name   = @INDEX_NAME
   AND column_name  = @COLUMN_NAME;

SET @sql_stmt = IF (@v_index_exists = 0,
                    CONCAT('CREATE INDEX `', @INDEX_NAME, '` ON ', @SCHEMA_NAME, '.', @TABLE_NAME, ' (`', @COLUMN_NAME, '`)'),
                    CONCAT('SELECT "====> Index ''', @INDEX_NAME, ''' ON ''', @TABLE_NAME, ''' table already exists" AS "Info:" FROM dual')
                    );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query;

SET @sql_stmt =IF(@v_index_exists = 0, 
                  CONCAT('SELECT "====> Index ''', @INDEX_NAME, ''' has been created" AS "Info:" FROM dual'),
                  'SELECT "====> Nothing to create..." AS "Info:" FROM dual');
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query;

