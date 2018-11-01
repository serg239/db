/*
  Script:
    move_content_tables.sql 
  Description: 
    1. Move tables from static_content to static_catalog schema
    2. Move tables from semistatic_content to semistatic_catalog schema
  Notes:
    Basic statement:
      SELECT CONCAT('RENAME TABLE ', GROUP_CONCAT(@LF, table_schema, '.', table_name, ' TO ', @NEW_SCHEMA_NAME, '.', table_name), ';') AS stmt 
        FROM information_schema.tables 
       WHERE table_schema = @OLD_SCHEMA_NAME
       GROUP BY table_schema;
    Result:
      RENAME TABLE
        static_content.profile_rule_output TO static_catalog.profile_rule_output,
        static_content.allocation_lookup TO static_catalog.allocation_lookup,
        static_content.lookup_type TO static_catalog.lookup_type,
        static_content.lookup TO static_catalog.lookup,
        static_content.item_relation_type TO static_catalog.item_relation_type,
        static_content.ima_uom_lookup TO static_catalog.ima_uom_lookup,
        static_content.ima_store_hierarchy_to_uom TO static_catalog.ima_store_hierarchy_to_uom,
        static_content.file_type TO static_catalog.file_type,
        static_content.file_process_status TO static_catalog.file_process_status,
        static_content.store TO static_catalog.store,
        static_content.site TO static_catalog.site,
        static_content.file_error_code_lookup TO static_catalog.file_error_code_lookup,
        static_content.shc_status_lookup TO static_catalog.shc_status_lookup,
        static_content.catalog_consumer_lookup TO static_catalog.catalog_consumer_lookup,
        static_content.ban_type_deprecated TO static_catalog.ban_type_deprecated,
        static_content.shc_hier_hardline_softline_map TO static_catalog.shc_hier_hardline_softline_map,
        static_content.ban_mode_lookup_deprecated TO static_catalog.ban_mode_lookup_deprecated,
        static_content.rule_type TO static_catalog.rule_type,
        static_content.attribute_type TO static_catalog.attribute_type,
        static_content.rule_reason_group TO static_catalog.rule_reason_group,
        static_content.attribute_entry_type TO static_catalog.attribute_entry_type,
        static_content.rule_reason_code TO static_catalog.rule_reason_code,
        static_content.asset_type TO static_catalog.asset_type,
        static_content.rule_mode TO static_catalog.rule_mode,
        static_content.regex_lookup TO static_catalog.regex_lookup,
        static_content.asset_format TO static_catalog.asset_format;
*/

-- ====================================
-- 1. Move tables from 'static_content' to 'static_catalog' schema
-- ====================================

-- ====================================
-- 1.1. Create the NEW schema
-- ====================================
SET @OLD_SCHEMA_NAME = 'static_content';
SET @NEW_SCHEMA_NAME = 'static_catalog';
SET @LF = CHAR(10);

SET @is_schema_exists = 0;

-- Check if new schema exists
SELECT 1
  INTO @is_schema_exists
  FROM information_schema.schemata
 WHERE schema_name = @NEW_SCHEMA_NAME;
 
-- Statement
SET @sql_stmt = IF(@is_schema_exists = 0,
                   CONCAT('CREATE SCHEMA ', @NEW_SCHEMA_NAME, ' DEFAULT CHARACTER SET utf8 COLLATE utf8_bin'),
                   CONCAT('SELECT "====> Schema ''', @NEW_SCHEMA_NAME, ''' already exists" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- Message
SET @sql_stmt = IF(@is_schema_exists = 0,
                   CONCAT('SELECT "====> Schema ''', @NEW_SCHEMA_NAME, ''' has been created" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Schema ''', @NEW_SCHEMA_NAME, ''': Nothing to create..." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 1.2. Move tables
-- ====================================
-- SET @is_schema_exists = 0;
SET @sql_prep_stmt = CONCAT('SELECT "====> Schema ''', @NEW_SCHEMA_NAME, ''': Nothing to move..." AS "Info:" FROM dual');

-- 1.2.1. Statement
SET @sql_stmt = IF(@is_schema_exists = 0,
                   "SELECT CONCAT('RENAME TABLE ', GROUP_CONCAT(@LF, table_schema, '.', table_name, ' TO ', @NEW_SCHEMA_NAME, '.', table_name), ';') AS stmt 
                             INTO @sql_prep_stmt 
                             FROM information_schema.tables 
                            WHERE table_schema = @OLD_SCHEMA_NAME
                            GROUP BY table_schema",
                   @sql_prep_stmt
                  ); 
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- 1.2.2. Move tables
PREPARE query FROM @sql_prep_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 1.3. Drop OLD Schema
-- ====================================
SET @is_schema_exists = 0;

SELECT 1
  INTO @is_schema_exists
  FROM information_schema.schemata
 WHERE schema_name = @OLD_SCHEMA_NAME;

SET @sql_stmt = IF(@is_schema_exists = 1,
                   CONCAT('DROP SCHEMA ', @OLD_SCHEMA_NAME),
                   CONCAT('SELECT "====> Old ''', @OLD_SCHEMA_NAME, ''' schema already dropped." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- Message
SET @sql_stmt = IF(@is_schema_exists = 0,
                   CONCAT('SELECT "====> Schema ''', @OLD_SCHEMA_NAME, ''' has been dropped" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Schema ''', @OLD_SCHEMA_NAME, ''': Nothing to drop..." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 2. Move tables from 'semistatic_content' to 'semistatic_catalog' schema
-- ====================================

-- ====================================
-- 2.1. Create the new schema
-- ====================================
SET @OLD_SCHEMA_NAME = 'semistatic_content';
SET @NEW_SCHEMA_NAME = 'semistatic_catalog';

SET @is_schema_exists = 0;

-- Check if new schema exists
SELECT 1
  INTO @is_schema_exists
  FROM information_schema.schemata
 WHERE schema_name = @NEW_SCHEMA_NAME;
 
-- Statement 
SET @sql_stmt = IF(@is_schema_exists = 0,
                   CONCAT('CREATE SCHEMA ', @NEW_SCHEMA_NAME, ' DEFAULT CHARACTER SET utf8 COLLATE utf8_bin'),
                   CONCAT('SELECT "====> Schema ''', @NEW_SCHEMA_NAME, ''' already exists" AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- Message
SET @sql_stmt = IF(@is_schema_exists = 0,
                   CONCAT('SELECT "====> Schema ''', @NEW_SCHEMA_NAME, ''' has been created" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Schema ''', @NEW_SCHEMA_NAME, ''': Nothing to create..." AS "Info:" FROM dual')
                  );
-- SELECT @sql_stmt;
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 2.2. Move tables
-- ====================================
-- SET @is_schema_exists = 0;
SET @sql_prep_stmt = CONCAT('SELECT "====> Schema ''', @NEW_SCHEMA_NAME, ''': Nothing to move..." AS "Info:" FROM dual');

-- 2.2.1. Prepare statement
SET @sql_stmt = IF(@is_schema_exists = 0,
                   "SELECT CONCAT('RENAME TABLE ', GROUP_CONCAT(@LF, table_schema, '.', table_name, ' TO ', @NEW_SCHEMA_NAME, '.', table_name), ';') AS stmt 
                             INTO @sql_prep_stmt 
                             FROM information_schema.tables 
                            WHERE table_schema = @OLD_SCHEMA_NAME
                            GROUP BY table_schema",
                   @sql_prep_stmt
                  ); 
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- 2.2.2. Move tables
PREPARE query FROM @sql_prep_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 2.3. Drop OLD Schema
-- ====================================
SET @is_schema_exists = 0;

SELECT 1
  INTO @is_schema_exists
  FROM information_schema.schemata
 WHERE schema_name = @OLD_SCHEMA_NAME;

SET @sql_stmt = IF(@is_schema_exists = 1,
                   CONCAT('DROP SCHEMA ', @OLD_SCHEMA_NAME),
                   CONCAT('SELECT "====> Old ''', @OLD_SCHEMA_NAME, ''' schema already dropped." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- Message
SET @sql_stmt = IF(@is_schema_exists = 0,
                   CONCAT('SELECT "====> Schema ''', @OLD_SCHEMA_NAME, ''' has been dropped" AS "Info:" FROM dual'),
                   CONCAT('SELECT "====> Schema ''', @OLD_SCHEMA_NAME, ''': Nothing to drop..." AS "Info:" FROM dual')
                  );
PREPARE query FROM @sql_stmt;
EXECUTE query;
DEALLOCATE PREPARE query; 

-- ====================================
-- 3. Update schema names in 'elt.src_tables' table
-- ====================================

SET @OLD_SCHEMA_NAME = 'static_content';
SET @NEW_SCHEMA_NAME = 'static_catalog';

UPDATE elt.src_tables
   SET src_schema_name = @NEW_SCHEMA_NAME
 WHERE src_schema_name = @OLD_SCHEMA_NAME;
 
COMMIT; 

SET @OLD_SCHEMA_NAME = 'semistatic_content';
SET @NEW_SCHEMA_NAME = 'semistatic_catalog';

UPDATE elt.src_tables
   SET src_schema_name = @NEW_SCHEMA_NAME
 WHERE src_schema_name = @OLD_SCHEMA_NAME;

SELECT CONCAT("====> Updated schema names in 'elt.src_tables' table.") AS "Info:" FROM dual;
 
COMMIT;
