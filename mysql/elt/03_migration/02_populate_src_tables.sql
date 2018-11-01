/*
  Version:
    2011.10.31.01
  Script:
    02_populate_src_tables.sql
  Description:
    Insert list of ELT tables into src_tables table from schemas:
        DB1: account
             user
        DB2: static_content
             semistatic_content
             external_content
             load_catalog
             catalog
        DB3:
             ???
    Insert MASTER Table's PK column names for LOG tables
    Insert PK column names for MASTER tables
    Insert and modify Table Aliases
  Usage:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < 02_populate_src_tables.sql
  Note:
    Example of internal CALL:
      CALL elt.populate_src_tables (@err, 'db1', 'InnoDB', 'account', 'account; account_log', NULL, NULL, NULL, ';', TRUE);
                                           |      |         |          |                      |     |     |     |    |
                                           |      |         |          |                      |     |     |     |    +--- debug_mode 
                                           |      |         |          |                      |     |     |     +-------- lists_delimiter
                                           |      |         |          |                      |     |     +-------------- NOT LIKE table_list 
                                           |      |         |          |                      |     +-------------------- LIKE table_list
                                           |      |         |          |                      +-------------------------- NOT IN table_list
                                           |      |         |          +------------------------------------------------- IN table_list
                                           |      |         +------------------------------------------------------------ SRC schema_name
                                           |      +---------------------------------------------------------------------- Engine Type
                                           +----------------------------------------------------------------------------- HOST alias
*/

SET @old_sql_mode = (SELECT @@SQL_MODE);
SET @@SQL_MODE = '';

SET @DB1_HOST_ALIAS = 'db1';
SET @DB2_HOST_ALIAS = 'db2';

SET @DEBUG_MODE     = FALSE;
SET @LIST_DELIMITER = ';';

SET @DB_ENGINE_TYPE = 'InnoDB';  -- default 
-- SET @DB_ENGINE_TYPE = 'TokuDB';  -- new engine

-- Clear the table. Attn: FKs from control_downloads
-- TRUNCATE TABLE elt.src_tables;
-- ALTER TABLE elt.src_tables AUTO_INCREMENT = 1;

-- ============================================================================
--                       S E E D  D A T A (to src_tables)
-- ============================================================================

-- ====================================
-- ACCOUNT(db1).account
-- ------------------------------------
-- Replicated: Master Shard
-- Updated:    UI
-- ====================================

SET @src_schema_name     = 'account';
SET @in_table_list       = 'account; account_log';
SET @not_in_table_list   = NULL;
SET @like_table_list     = NULL;
SET @not_like_table_list = NULL;

CALL elt.populate_src_tables (@err, 
                              @DB1_HOST_ALIAS,
                              @DB_ENGINE_TYPE,
                              @src_schema_name, 
                              @in_table_list, 
                              @not_in_table_list, 
                              @like_table_list, 
                              @not_like_table_list, 
                              @LIST_DELIMITER, 
                              @DEBUG_MODE);

SELECT CONCAT('====> Schema ''', @src_schema_name, ''': OK') AS "Info:" FROM dual;

-- ====================================
-- USER(db1).user
-- ------------------------------------
-- Replicated: Master Shard
-- Updated:    UI
-- ====================================

SET @src_schema_name     = 'user';
SET @in_table_list       = 'user; user_log';
SET @not_in_table_list   = NULL;
SET @like_table_list     = NULL;
SET @not_like_table_list = NULL;

CALL elt.populate_src_tables (@err, 
                              @DB1_HOST_ALIAS,
                              @DB_ENGINE_TYPE,
                              @src_schema_name, 
                              @in_table_list, 
                              @not_in_table_list, 
                              @like_table_list, 
                              @not_like_table_list, 
                              @LIST_DELIMITER, 
                              @DEBUG_MODE);

SELECT CONCAT('====> Schema ''', @src_schema_name, ''': OK') AS "Info:" FROM dual;

-- ====================================
-- CATALOG(db2).static_content 
-- ------------------------------------
-- Replicated: Duplicated on all Shards
-- Updated:    Release (once a month)
-- ====================================

--   AND table_name NOT LIKE 'ban_%'
--   AND table_name NOT LIKE 'file_%'
--   AND table_name NOT LIKE 'ima_%'

SET @src_schema_name     = 'static_content';
SET @in_table_list       = NULL;
SET @not_in_table_list   = NULL;
SET @like_table_list     = NULL;
SET @not_like_table_list = 'ban_%; file_%; ima_%; rule_%';

CALL elt.populate_src_tables (@err, 
                              @DB2_HOST_ALIAS,
                              @DB_ENGINE_TYPE,
                              @src_schema_name,
                              @in_table_list,
                              @not_in_table_list,
                              @like_table_list,
                              @not_like_table_list,
                              @LIST_DELIMITER,
                              @DEBUG_MODE);

SELECT CONCAT('====> Schema ''', @src_schema_name, ''': OK') AS "Info:" FROM dual;

-- ====================================
-- CATALOG(db2).semistatic_content
-- ------------------------------------
-- Replicated: Master Shard -> Slave Shards
-- Updated:    UI (M->S, not parallel), Release (M->S, not parallel)
-- ====================================

--   AND table_name NOT LIKE ('ban_%')
--   AND table_name NOT LIKE ('profile%')
--   AND table_name NOT IN ('metadata_asset')

SET @src_schema_name     = 'semistatic_content';
SET @in_table_list       = NULL; 
SET @not_in_table_list   = NULL;
SET @like_table_list     = NULL;
SET @not_like_table_list = 'ban_%; %_archive; profile%; rule%; metadata_asset%';

CALL elt.populate_src_tables (@err, 
                              @DB2_HOST_ALIAS,
                              @DB_ENGINE_TYPE,
                              @src_schema_name,
                              @in_table_list,
                              @not_in_table_list,
                              @like_table_list,
                              @not_like_table_list,
                              @LIST_DELIMITER,
                              @DEBUG_MODE);

SELECT CONCAT('====> Schema ''', @src_schema_name, ''': OK') AS "Info:" FROM dual;

-- ====================================
-- CATALOG(db2).load_catalog -- Before other DB2 schemas (shards)
-- ------------------------------------
-- Replicated: Master Shard
-- Updated:    DB Processes
-- ====================================

-- ====================================
-- Tables for Reports:
--   3.3.05 new_item_inventory
--   3.3.07 new_vendor_packs
--   3.3.08 gofer_instore_date
-- ====================================
SET @src_schema_name     = 'load_catalog';
SET @in_table_list       = 'shard_account_list';     -- 'core_item; oi_item; oi_ksn; oi_pkg; oi_vend_pkg' 
SET @not_in_table_list   = NULL;
SET @like_table_list     = NULL;
SET @not_like_table_list = NULL;

CALL elt.populate_src_tables (@err, 
                              @DB2_HOST_ALIAS,
                              @DB_ENGINE_TYPE,
                              @src_schema_name,
                              @in_table_list,
                              @not_in_table_list,
                              @like_table_list,
                              @not_like_table_list,
                              @LIST_DELIMITER,
                              @DEBUG_MODE);

SELECT CONCAT('====> Schema ''', @src_schema_name, ''': OK') AS "Info:" FROM dual;

/*
   NOTES:
     We need in the following tables/fields from (db2).load_catalog schema:
     oi_item.rsos_ind                              [3.3.07. Email Reports: New Vendor Packs Creates] 
     oi_ksn.exploding_assortment_ksn_number        [3.3.05. Email Reports: Kmart New Items Inventory Report]
     core_item.srs_bus_nbr AS core_business_number [3.3.05. Email Reports: Kmart New Items Inventory Report]
*/

-- ====================================
-- CATALOG(db2).external_content
-- ------------------------------------
-- Replicated: Master Shard
-- Updated:    UI
-- Exception:  external_item is NOT replicated across Shards (account_id) ???
--             Replicated: Master Shard -> Slave Shards
--             Updated:    UI (M->S, not parallel), Release (M->S, not parallel)
--             Rule [per Shard]: external_content.external_item.account_id = load_catalog.shard_account_list.account_id
-- ====================================

SET @src_schema_name     = 'external_content';
SET @in_table_list       = 'external_item; external_attribute; external_attribute_mapping; external_attribute_value'; -- external_item_attribute_value'; 
SET @not_in_table_list   = NULL;
SET @like_table_list     = NULL;
SET @not_like_table_list = NULL;

CALL elt.populate_src_tables (@err,
                              @DB2_HOST_ALIAS,
                              @DB_ENGINE_TYPE,
                              @src_schema_name,
                              @in_table_list,
                              @not_in_table_list,
                              @like_table_list,
                              @not_like_table_list,
                              @LIST_DELIMITER,
                              @DEBUG_MODE);

/*
   AND table_name NOT IN   ('external_item_attribute_value');
*/  

SELECT CONCAT('====> Schema ''', @src_schema_name, ''': OK') AS "Info:" FROM dual;

-- ====================================
-- CATALOG(db2).catalog
-- ------------------------------------
-- Replicated: Master Shard
-- Updated:    UI
-- Exception:  content_item is replicated across Shards (account_id)
--             Replicated: Master Shard -> Slave Shards
--             Updated:    UI (M->S, not parallel), Release (M->S, not parallel)
--             Rule [per Shard]: catalog.content_item.owner_account_id = load_catalog.shard_account_list.account_id
-- ====================================

SET @src_schema_name     = 'catalog';
SET @in_table_list       = NULL;
SET @not_in_table_list   = 'item_promotion; item_promotion_log; enrichment_control; catalog_export_job_control; eventual_consistency_job_control; search_job_control; item_content_change_history; item_content_change_snapshot; content_item_transaction_log; external_brand; site_mapping; content_item_sync; item_ban_rule; item_ban_rule2; item_sticky_ban_list; metadata_asset_log; rebuild_item_log; z; z1; purge_item_content_change_history_job_control; content_item_attribute_value; content_item_attribute_value_log; item_relation_log; item_relation_detail_log; item_hierarchy_log; item_site_log'; 
SET @like_table_list     = NULL;
SET @not_like_table_list = '%_archive; %_migration; %_deprecated; to_%; solr_%; profile_%; promotion%; ban_%; bad_%; item_rule_%';

CALL elt.populate_src_tables (@err,
                              @DB2_HOST_ALIAS,
                              @DB_ENGINE_TYPE,
                              @src_schema_name,
                              @in_table_list,
                              @not_in_table_list,
                              @like_table_list,
                              @not_like_table_list,
                              @LIST_DELIMITER,
                              @DEBUG_MODE);
                              
SELECT CONCAT('====> Schema ''', @src_schema_name, ''': OK') AS "Info:" FROM dual;

/*
   AND table_name NOT LIKE ('%_archive')
   AND table_name NOT LIKE ('%_migration')
   AND table_name NOT LIKE ('to_%')
   AND table_name NOT LIKE ('solr_%')
   AND table_name NOT LIKE ('profile_%')
   AND table_name NOT LIKE ('promotion%')
   AND table_name NOT IN   ('item_promotion', 'item_promotion_log')
   AND table_name NOT IN   ('enrichment_control', 'catalog_export_job_control', 'eventual_consistency_job_control', 'search_job_control') 
   AND table_name NOT IN   ('item_content_change_history', 'item_content_change_snapshot')
   AND table_name NOT IN   ('content_item_transaction_log')
   AND table_name NOT IN   ('external_brand', 'site_mapping')
   AND table_name NOT IN   ('content_item_sync')
   AND table_name NOT IN   ('item_ban_rule', 'item_ban_rule2', 'ban_rule_log', 'item_sticky_ban_list')
   AND table_name NOT IN   ('metadata_asset_log', 'rebuild_item_log', 'z', 'z1', 'purge_item_content_change_history_job_control')
   AND table_name NOT IN   ('content_item_attribute_value', 'content_item_attribute_value_log')
   AND table_name NOT IN   ('item_relation_log', 'item_relation_detail_log', 'item_hierarchy_log', 'item_site_log')
*/

-- ====================================
-- Provide uniqueness of Table's Aliases
-- ====================================

-- a -> acc
UPDATE elt.src_tables 
   SET src_table_alias = 'acc'
 WHERE src_schema_name = 'account'
   AND src_table_name  = 'account';

-- a -> ass
UPDATE elt.src_tables 
   SET src_table_alias = 'ass'
 WHERE src_schema_name = 'catalog'
   AND src_table_name  = 'asset';

-- al -> accl
UPDATE elt.src_tables 
   SET src_table_alias = 'accl'
 WHERE src_schema_name = 'account'
   AND src_table_name  = 'account_log';       

-- al -> allk
UPDATE elt.src_tables 
   SET src_table_alias = 'allk'
 WHERE src_schema_name = 'static_content'
   AND src_table_name  = 'allocation_lookup'; 

-- ea -> eacc
UPDATE elt.src_tables
   SET src_table_alias = 'eacc'
 WHERE src_schema_name = 'external_content'
   AND src_table_name  = 'external_account';

-- ir -> irej
UPDATE elt.src_tables
   SET src_table_alias = 'irej'
 WHERE src_schema_name = 'catalog'
   AND src_table_name  = 'item_rejection';    

-- s -> site
UPDATE elt.src_tables
   SET src_table_alias = 'st'
 WHERE src_schema_name = 'static_content'
   AND src_table_name  = 'site';

-- ====================================
-- Avoid MySQL key words in Table's Aliases
-- ====================================

-- ssl -> sstl
UPDATE elt.src_tables
   SET src_table_alias = 'sstl'
 WHERE src_schema_name = 'static_content'
   AND src_table_name  = 'shc_status_lookup';

-- is -> ist
UPDATE elt.src_tables 
   SET src_table_alias = 'ist'
 WHERE src_schema_name = 'catalog'
   AND src_table_name  = 'item_site';

COMMIT;

SELECT CONCAT('====> Update Table Aliases: OK') AS "Info:" FROM dual;

-- ====================================
-- Next Steps:
--  1. Validate tables
--  2. Fix conditions for not valid tables
--  3. Migrate Data from remote schemas to DB_STAGE local schema
--  All these is from one procedure:
--    CALL elt.get_elt_data (@err, 'STAGE', 'TokuDB', @DEBUG_MODE);
-- ====================================

SET @@SQL_MODE = @old_sql_mode;
