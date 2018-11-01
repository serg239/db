REM ===========================================================================
REM DDL: <>/LOG_DUPS/release_scripts/*.sql
REM ===========================================================================

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\trunk\log_dups\release_scripts\00_drop_create_log_dups_schema.sql

REM ===========================================================================
REM FUNCTIONS AND PROCEDURES: <>/LOG_DUPS/procs/*.sql 
REM ===========================================================================

-- create procedure in ELT schema
mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\trunk\log_dups\procs\01_create_proc_create_tables_from_src.sql

REM 1. Create tables in 'log_dups' schema                                                                              LOG only, Indexes, Debug
mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "CALL elt.create_tables_from_src (@err_num, 'log_dups', 'MyISAM', TRUE, FALSE, FALSE);" 

REM 2. Delete (after Saving) Repeated Rows
mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\trunk\log_dups\procs\02_create_proc_delete_repeated_log_rows.sql

mysql -h dbtrunk-db3 -u data_owner -pdata_owner -e "CALL log_dups.delete_repeated_log_rows (@err_num, 'STAGE', TRUE);" 


REM ===========================================================================
REM DML: SEED DATA: <>/LOG_DUPS/migration/*.sql
REM ===========================================================================

mysql -h dbtrunk-db3 -u data_owner -pdata_owner < C:\Sears\trunk\log_dups\migration\01_remove_dups_from_log_tables.sql

REM ===========================================================================
REM Migration: patch source and dbtest-db3
REM ===========================================================================

./db/bin/release.sh -v -d -a -h dbtest-db3 -u data_owner -pdata_owner -P 3306 -m report > reportDW_on_test_prepare.log

mysql -h dbtest-db3 -P 3306 -u data_owner -e "
UPDATE elt.shard_profiles 
   SET host_ip_address = CASE WHEN host_alias = 'db1' THEN 'dbpatch-db1' 
                              WHEN host_alias = 'db2' THEN 'dbpatch-db2' 
                              ELSE 'dbtrunk-db2' 
                         END,
       host_port_num = CASE WHEN host_alias = 'db1' THEN '4000' 
                            WHEN host_alias = 'db2' THEN '5001' 
                            ELSE '5001' 
                         END;
                         
COMMIT;
"

nohup ./db/bin/release.sh -v -h dbtest-db3 -u data_owner -pdata_owner -P 3306 -m report -M > reportDW_on_test_migrate.log 2>&1


