REM ===========================================================================
REM CLEAR DB_ELT DATABASE (DROP SCHEMAS)
REM ===========================================================================

mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "DROP SCHEMA IF EXISTS db_stage"
mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "DROP SCHEMA IF EXISTS db_delta"
mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "DROP SCHEMA IF EXISTS db_link"

mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "DROP SCHEMA IF EXISTS elt"

REM ===========================================================================
REM DDL: <>/DB_ELT/01_release_scripts/*.sql
REM ===========================================================================

REM mysql -h 127.0.0.1 -uroot < C:\Sears\ELT\01_release_scripts\00_create_users_grants.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\01_release_scripts\01_create_schema_elt.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\01_release_scripts\02_create_tables_elt.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\01_release_scripts\03_populate_db_shards.sql

REM ===========================================================================
REM FUNCTIONS AND PROCEDURES: <>/DB_ELT/02_procs/*.sql 
REM ===========================================================================

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\00_create_func_fed_table_available.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\00_create_func_get_last_migrated_table.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\00_create_func_check_if_elt_is_running.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\00_create_func_initcap.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\00_create_func_split_condition_string.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\00_create_func_translate.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\01_create_proc_create_info_link_tables.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\02_create_proc_populate_src_tables.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\03_create_proc_validate_src_tables.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\04_create_proc_fix_cond_for_not_valid_tables.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\05_create_proc_create_elt_schema.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\06_create_proc_add_elt_table.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\07_create_proc_remove_elt_table.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\08_create_proc_add_elt_shard.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\09_create_proc_remove_elt_shard.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\10_create_proc_check_modify_columns.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\12_create_proc_drop_elt_table.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\14_create_proc_check_modify_indexes.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\15_create_proc_create_elt_table.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\16_create_proc_drop_indexes_on_column.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\19_create_proc_get_initial_rows.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\20_create_proc_load_elt_data.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\21_create_proc_get_elt_data.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\02_procs\22_create_proc_delete_repeated_log_rows.sql

REM ===========================================================================
REM DML: SEED DATA: <>/DB_ELT/03_migration/*.sql
REM ===========================================================================
REM migration scripts: 
REM OK
mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\03_migration\01_create_info_link_tables.sql

REM OK
mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\03_migration\02_populate_src_tables.sql

REM Validate all tables
mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "CALL elt.validate_src_tables (@err, NULL, NULL, FALSE);"

REM Fix possible issues after validation
mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "CALL elt.fix_cond_for_not_valid_tables (@err, FALSE);"

REM Create "db_link" schema
REM mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "CALL elt.create_elt_schemas (@err, 'LINK',  NULL, FALSE)"

REM Create "db_stage" schema
REM mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "CALL elt.create_elt_schemas (@err, 'STAGE', 'TokuDB', FALSE)"

REM Get number of rows in all migrated tables
REM mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "CALL elt.get_initial_rows (@err, NULL, NULL, FALSE)"


REM Migrate data (with basic fields' validation)
REM CALL elt.get_elt_data (@err, 'STAGE', TRUE, FALSE); 
mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\ELT\03_migration\03_migrate_stage_data.sql

REM
REM OR
REM Migrate data (no validation)
REM mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "CALL elt.get_elt_data (@err, 'STAGE', FALSE, FALSE)"


REM ===================================
REM Refresh elt.shard_profiles
REM ===================================
SET @old_fk_checks = (SELECT @@FOREIGN_KEY_CHECKS);
SET @@FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE elt.shard_profiles;
ALTER TABLE elt.shard_profiles AUTO_INCREMENT = 1;
SET @@FOREIGN_KEY_CHECKS = @old_fk_checks;

REM ===================================
REM Refresh elt.src_tables
REM ===================================
REM SET @old_fk_checks = (SELECT @@FOREIGN_KEY_CHECKS);
REM SET @@FOREIGN_KEY_CHECKS = 0;
REM TRUNCATE TABLE elt.src_tables;
REM ALTER TABLE elt.src_tables AUTO_INCREMENT = 1;
REM SET @@FOREIGN_KEY_CHECKS = @old_fk_checks;

REM mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "SELECT elt.get_last_migrated_table() AS last_migrated_table"

REM ALTER TABLE elt.src_tables
REM   ADD COLUMN initial_rows INTEGER NOT NULL DEFAULT 0 COMMENT 'Table''s Row Count before first migration'
REM AFTER comments;


(data_owner@dbtrunk-db3) [(none)]> SHOW ENGINES;
+------------+---------+--------------------------------------------------------------------------------------------------+--------------+------+------------+
| Engine     | Support | Comment                                                                                          | Transactions | XA   | Savepoints |
+------------+---------+--------------------------------------------------------------------------------------------------+--------------+------+------------+
| MEMORY     | YES     | Hash based, stored in memory, useful for temporary tables                                        | NO           | NO   | NO         |
| MRG_MYISAM | YES     | Collection of identical MyISAM tables                                                            | NO           | NO   | NO         |
| FEDERATED  | YES     | FederatedX pluggable storage engine                                                              | YES          | NO   | YES        |
| BLACKHOLE  | YES     | /dev/null storage engine (anything you write to it disappears)                                   | NO           | NO   | NO         |
| CSV        | YES     | CSV storage engine                                                                               | NO           | NO   | NO         |
+------------+---------+--------------------------------------------------------------------------------------------------+--------------+------+------------+
| TokuDB     | YES     | Tokutek TokuDB Storage Engine with Fractal Tree(tm) Technology                                   | YES          | NO   | YES        |
+------------+---------+--------------------------------------------------------------------------------------------------+--------------+------+------------+
| ARCHIVE    | YES     | Archive storage engine                                                                           | NO           | NO   | NO         |
| MyISAM     | YES     | Default engine as of MySQL 3.23 with great performance                                           | NO           | NO   | NO         |
+------------+---------+--------------------------------------------------------------------------------------------------+--------------+------+------------+
| InnoDB     | DEFAULT | XtraDB engine based on InnoDB plugin. Supports transactions, row-level locking, and foreign keys | YES          | YES  | YES        |
+------------+---------+--------------------------------------------------------------------------------------------------+--------------+------+------------+
| PBXT       | YES     | High performance, multi-versioning transactional engine                                          | YES          | YES  | NO         |
| Aria       | YES     | Crash-safe tables with MyISAM heritage                                                           | YES          | NO   | NO         |
+------------+---------+--------------------------------------------------------------------------------------------------+--------------+------+------------+
11 rows in set (0.00 sec)

ALTER TABLE v_dst_schema_name, ".", table_name ADD COLUMN column_name VARCHAR(24) NOT NULL (NULL) DEFAULT [] PRIMARY KEY;

ALTER TABLE v_dst_schema_name, ".", table_name DROP COLUMN column_name;

SET @stmt = "ALTER TABLE semistatic_content.migration ADD COLUMN test_id VARCHAR(24) NOT NULL DEFAULT 0 PRIMARY KEY";

SELECT CASE WHEN POSITION('ADD' IN @stmt) > 0 THEN 'ADD'
            ELSE 'DROP'
       END AS action,
       SUBSTRING_INDEX(LTRIM(SUBSTRING_INDEX(@stmt, 'COLUMN', -1)), ' ', 1)  AS src_column_name,
       SUBSTR(LTRIM(SUBSTRING_INDEX(@stmt, 'COLUMN', -1)), 
              POSITION(' ' IN LTRIM(SUBSTRING_INDEX(@stmt, 'COLUMN', -1))) + 1) AS column_attributes
  FROM dual;
  
ALTER TABLE db_stage.content_item_external_item_mapping DROP COLUMN external_account_id;
ALTER TABLE db_stage.content_item_external_item_mapping DROP COLUMN derived_status;  

TRUNCATE TABLE elt.ddl_column_changes;

'ALTER TABLE db_stage.content_item_external_item_mapping DROP COLUMN disabled_dtm'
'ALTER TABLE db_stage.content_item_external_item_mapping ADD COLUMN external_account_id BIGINT(20) NOT NULL'
'ALTER TABLE db_stage.content_item_external_item_mapping DROP COLUMN account_id'
'ALTER TABLE db_stage.content_item_external_item_mapping ADD COLUMN derived_status BIGINT(20) NOT NULL DEFAULT 0'


'ALTER TABLE db_stage.content_item_external_item_mapping DROP COLUMN disabled_dtm TIMESTAMP NOT NULL DEFAULT '1969-12-31 22:00:00''
'ALTER TABLE db_stage.content_item_external_item_mapping ADD COLUMN external_account_id BIGINT(20) NOT NULL'
'ALTER TABLE db_stage.content_item_external_item_mapping DROP COLUMN account_id BIGINT(20) NOT NULL'
'ALTER TABLE db_stage.content_item_external_item_mapping ADD COLUMN derived_status BIGINT(20) NOT NULL DEFAULT '0''


'ALTER TABLE db_stage.content_item_external_item_mapping DROP COLUMN disabled_dtm'
'ALTER TABLE db_stage.content_item_external_item_mapping ADD COLUMN external_account_id BIGINT(20) NOT NULL'
'ALTER TABLE db_stage.content_item_external_item_mapping DROP COLUMN account_id'
'ALTER TABLE db_stage.content_item_external_item_mapping ADD COLUMN derived_status BIGINT(20) NOT NULL DEFAULT '0''

'ALTER TABLE db_link.content_item_external_item_mapping DROP COLUMN disabled_dtm' -> ALTER TABLE db_link.db2_01_catalog_content_item_external_item_mapping DROP COLUMN disabled_dtm
FED tables could not be altered!!!


ALTER TABLE elt.src_tables
ADD COLUMN db_engine_type VARCHAR(16)   NOT NULL DEFAULT 'InnoDB'     COMMENT 'DST Table Engine' 
AFTER dst_table_name;

ALTER TABLE elt.ddl_index_changes
ADD COLUMN shard_number CHAR(2) NOT NULL DEFAULT '01' COMMENT 'Shard Number [01|02|...]'
AFTER host_alias;

ALTER TABLE elt.ddl_index_changes DROP COLUMN shard_number;
ALTER TABLE elt.ddl_index_changes DROP COLUMN src_index_name;
ALTER TABLE elt.ddl_index_changes DROP COLUMN dst_index_name;
ALTER TABLE elt.ddl_index_changes
ADD COLUMN index_name VARCHAR(64) COMMENT 'Index Name'
AFTER src_table_name;

ALTER TABLE elt.ddl_column_changes DROP COLUMN applied_to_link;

ALTER TABLE elt.ddl_index_changes DROP COLUMN applied_to_link;


ALTER TABLE elt.ddl_index_changes
ADD COLUMN elt_schema_type VARCHAR(16) NOT NULL DEFAULT 'STAGE' COMMENT 'Schema Type [STAGE|DELTA]'
AFTER ddl_index_change_id;

ALTER TABLE elt.ddl_column_changes
ADD COLUMN elt_schema_type VARCHAR(16) NOT NULL DEFAULT 'STAGE' COMMENT 'Schema Type [STAGE|DELTA]'
AFTER ddl_column_change_id;


DROP TABLE db_link.db2_01_catalog_content_item_external_item_mapping

CREATE TABLE db_link.db2_01_catalog_content_item_external_item_mapping
(
  content_item_external_item_mapping_id BIGINT(20)     NOT NULL,
  content_item_id                       BIGINT(20)     NOT NULL,
  external_item_id                      BIGINT(20)     NOT NULL,
  created_dtm                           TIMESTAMP      NOT NULL DEFAULT TIMESTAMP '2000-01-01 00:00:00',
  modified_dtm                          TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status                                TINYINT(4)     NOT NULL,
  owner_account_id                      BIGINT(20)     NOT NULL,
  last_enriched_dtm                     TIMESTAMP      NOT NULL DEFAULT TIMESTAMP '2000-01-01 00:00:00',
  modified_id                           BIGINT(20)     NOT NULL,
  external_account_id                   BIGINT(20)     NOT NULL,
  exclusion_status_id                   TINYINT(4)     NOT NULL DEFAULT 0,
  derived_status                        BIGINT(20)     NOT NULL DEFAULT 0,
  KEY db2_01_catalog_content_item_external_item_$last_enriched_dtm_idx (last_enriched_dtm),
  KEY db2_01_catalog_content_item_external_item_m$external_item_id_idx (external_item_id),
  PRIMARY KEY db2_01_catalog_content_$content_item_external_item_mapping_id_pk (content_item_external_item_mapping_id),
  UNIQUE KEY db2_01_c$content_item_id_external_account_id_derived_status_uidx (content_item_id, external_account_id, derived_status)
)
ENGINE = FEDERATED 
DEFAULT CHARSET = utf8 
COLLATE = utf8_bin 
CONNECTION = 'mysql://shc_batch:shc_batch@dbtrunk-db2:3306/catalog/content_item_external_item_mapping'

INSERT INTO elt.tmp_pk_ids$3711693830519 (pk_id) 
SELECT tmp.content_item_external_item_mapping_id AS pk_id
  FROM db_link.tmp_link_pk_ids$65260474258344 tmp
 WHERE tmp.modified_dtm BETWEEN '2000-01-01 00:00:00' AND '2011-10-17 15:07:55'
 
INSERT INTO db_stage.content_item_external_item_mapping
(
 content_item_external_item_mapping_id, content_item_id, external_item_id, created_dtm, modified_dtm, status, owner_account_id, last_enriched_dtm, modified_id, external_account_id, exclusion_status_id, derived_status
) 
SELECT 
       cieim.content_item_external_item_mapping_id,
       cieim.content_item_id,
       cieim.external_item_id,
       cieim.created_dtm,
       cieim.modified_dtm,
       cieim.status,
       cieim.owner_account_id,
       cieim.last_enriched_dtm,
       cieim.modified_id,
       cieim.external_account_id,
       cieim.exclusion_status_id,
       cieim.derived_status
  FROM db_link.db2_01_catalog_content_item_external_item_mapping cieim
  FORCE INDEX (PRIMARY)
  INNER JOIN elt.tmp_block_pk_ids$3711693830519 tmp
    ON cieim.content_item_external_item_mapping_id = tmp.pk_id
  INNER JOIN db_link.db2_01_load_catalog_shard_account_list sal      
    ON cieim.owner_account_id = sal.account_id
 WHERE cieim.modified_dtm BETWEEN '2000-01-01 00:00:00' AND '2011-10-17 15:07:55';
 
UNIQUE KEY `db2_01_c$content_item_id_external_account_id_derived_status_uidx` (`content_item_id`,`external_account_id`,`derived_status`),

UNIQUE KEY `content_item$content_item_id_account_id_disabled_dtm_status_uidx` (`content_item_id`,`status`),



 
SELECT COUNT(*) FROM catalog.content_item_external_item_mapping;
+----------+
|   115597 |
+----------+
(data_owner@dbtrunk-db2) [(none)]> SELECT COUNT(*) FROM catalog.content_item_external_item_mapping;
+----------+
|   115597 |
+----------+
(data_owner@dbtrunk-db2) [(none)]> SELECT COUNT(DISTINCT content_item_id, external_account_id, derived_status)
    -> FROM catalog.content_item_external_item_mapping;
+----------------------------------------------------------------------+
|                                                               115597 |
+----------------------------------------------------------------------+
(data_owner@dbtrunk-db2) [(none)]> SELECT COUNT(content_item_external_item_mapping_id) FROM catalog.content_item_external_item_mapping;
+----------------------------------------------+
|                                       115597 |
+----------------------------------------------+
1 row in set (0.02 sec) 
 

===============================================================================

CREATE TABLE IF NOT EXISTS db_link.tmp_link_pk_ids$2750168836442
(
content_item_external_item_mapping_id BIGINT NOT NULL,
modified_dtm    TIMESTAMP NOT NULL
)
ENGINE = FEDERATED
CONNECTION = 'mysql://shc_batch:shc_batch@dbtrunk-db2:3306/catalog/content_item_external_item_mapping'

CREATE TABLE IF NOT EXISTS elt.tmp_pk_ids$45419698902796
(
pk_id  BIGINT NOT NULL,
PRIMARY KEY (pk_id)
)
ENGINE = InnoDB

INSERT INTO elt.tmp_pk_ids$45419698902796 (pk_id) 
SELECT tmp.content_item_external_item_mapping_id AS pk_id
  FROM db_link.tmp_link_pk_ids$2750168836442 tmp
 WHERE tmp.modified_dtm BETWEEN '2000-01-01 00:00:00' AND '2011-10-17 15:07:55'

DROP TABLE IF EXISTS db_link.tmp_link_pk_ids$2750168836442

CREATE TABLE IF NOT EXISTS elt.tmp_block_pk_ids$45419698902796(
pk_id  BIGINT NOT NULL,
PRIMARY KEY (pk_id)
)
ENGINE = InnoDB

SELECT IFNULL(COUNT(pk_id), 0) INTO @v_pk_num_rows FROM elt.tmp_pk_ids$45419698902796    -- 111001 ???

UPDATE elt.src_tables
   SET initial_rows = 111001
 WHERE host_alias      = 'db2'
   AND shard_number    = '01'
   AND src_schema_name = 'catalog'
   AND src_table_name  = 'content_item_external_item_mapping'
   AND initial_rows = 0
   
TRUNCATE TABLE elt.tmp_block_pk_ids$45419698902796

INSERT INTO elt.tmp_block_pk_ids$45419698902796 (pk_id)
SELECT pk_id
  FROM elt.tmp_pk_ids$45419698902796
 ORDER BY pk_id
 LIMIT 0, 100000
 
CREATE INDEX tmp_block_pk_ids$45419698902796$pk_id_idx ON elt.tmp_block_pk_ids$45419698902796 (pk_id)

INSERT INTO db_stage.content_item_external_item_mapping
(
 content_item_external_item_mapping_id, content_item_id, external_item_id, created_dtm, modified_dtm, status, owner_account_id, last_enriched_dtm, modified_id, external_account_id, exclusion_status_id, derived_status
) 
SELECT 
       cieim.content_item_external_item_mapping_id,
       cieim.content_item_id,
       cieim.external_item_id,
       cieim.created_dtm,
       cieim.modified_dtm,
       cieim.status,
       cieim.owner_account_id,
       cieim.last_enriched_dtm,
       cieim.modified_id,
       cieim.external_account_id,
       cieim.exclusion_status_id,
       cieim.derived_status
  FROM db_link.db2_01_catalog_content_item_external_item_mapping cieim
  FORCE INDEX (PRIMARY)
  INNER JOIN elt.tmp_block_pk_ids$45419698902796 tmp
    ON cieim.content_item_external_item_mapping_id = tmp.pk_id
  INNER JOIN db_link.db2_01_load_catalog_shard_account_list sal
    ON cieim.owner_account_id = sal.account_id
  WHERE cieim.modified_dtm BETWEEN '2000-01-01 00:00:00' AND '2011-10-17 15:07:55'
;

INSERT INTO db_stage.content_item_external_item_mapping
(
 content_item_external_item_mapping_id, content_item_id, external_item_id, created_dtm, modified_dtm, status, owner_account_id, last_enriched_dtm, modified_id, external_account_id, exclusion_status_id, derived_status
) 
SELECT 
       cieim.content_item_external_item_mapping_id,
       cieim.content_item_id,
       cieim.external_item_id,
       cieim.created_dtm,
       cieim.modified_dtm,
       cieim.status,
       cieim.owner_account_id,
       cieim.last_enriched_dtm,
       cieim.modified_id,
       cieim.external_account_id,
       cieim.exclusion_status_id,
       cieim.derived_status
  FROM db_link.db2_01_catalog_content_item_external_item_mapping cieim
  FORCE INDEX (PRIMARY)
  INNER JOIN elt.tmp_block_pk_ids$99918064568114 tmp
    ON cieim.content_item_external_item_mapping_id = tmp.pk_id
  INNER JOIN db_link.db2_01_load_catalog_shard_account_list sal
    ON cieim.owner_account_id = sal.account_id
   WHERE cieim.modified_dtm BETWEEN '2000-01-01 00:00:00' AND '2011-10-17 15:07:55'
   
TRUNCATE TABLE elt.ddl_column_changes;   

szaytsev@dbtrunk-db3 > vmstat 5 20
procs -----------memory---------- ---swap-- -----io---- --system-- -----cpu-----
 r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st
 2  0      0 183548    108 5796812    0    0     1    28    2    0  0  0 100  0  0
 0  0      0 173164    108 5227152    0    0     1  3996 14364 6247  4 10 86  0  0
 1  0      0 176384    108 4640516    0    0     2  5524 13702 8079  4  5 90  0  0
 2  0      0 170264    108 4062216    0    0     6  3957 13716 8550  4  5 91  0  0
 1  0      0 173084    108 3450532    0    0     6  4654 13214 8184  5  5 91  0  0
 0  0      0 162952    104 2873220    0    0     3  6051 13501 8634  4  4 91  0  0
 2  0      0 198412     92 2178968    0    0     3  3854 17131 7329  4  9 87  0  0
 1  0      0 284032     92 1562884    0    0     4  3727 14591 5340  3 12 85  0  0
 2  0      0 242064     76 926172    0    0     9  5041 17293 7393  4  9 87  0  0
 0  0      0 12991544     76 595844    0    0     5  6404 20117 6317  3 15 82  0  0  <--------- ??? 21:40
 0  0      0 13024796     76 694708    0    0  5278 12172 4876 2256  3  1 95  0  0
 1  0      0 13015388     76 703336    0    0     7  4596 5557 2438  2  1 97  0  0
 0  0      0 12999640     76 710208    0    0    33  4607 6449 2807  2  1 97  0  0
 1  0      0 12983272     76 718204    0    0     5  5479 6413 2808  2  1 97  0  0
 1  0      0 12966036     76 726284    0    0     4  4486 6447 2805  2  1 97  0  0
 0  0      0 12948924     76 734328    0    0     4  4928 6440 2810  2  1 97  0  0
 1  0      0 12933080     76 741968    0    0     4 16310 6092 2647  2  1 97  0  0
 0  1      0 12915836     76 749972    0    0     4  4507 6440 2791  2  1 97  0  0
 0  0      0 12900212     76 756708    0    0     4  5011 6455 2808  2  1 97  0  0
 0  0      0 12882976     76 764904    0    0     6  5766 6422 2806  2  1 97  0  0
szaytsev@dbtrunk-db3 > who


nohup mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "CALL elt.get_elt_data (@err, 'STAGE', FALSE, FALSE)" > migrate.log &
