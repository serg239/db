# =============================================================================
# State:
#   //dev/test/proj/test_mongodb/init.sls
# Description:
#   Test MongoDB configuration and status
# Usage:
#   salt 'proj1-dev1' state.sls proj.test_mongodb saltenv=test
# =============================================================================
{% set m = salt['pillar.get']('mongodb', {}) %}
{% set admin_user    = m.get('adminUser', '') %}
{% set admin_pwd     = m.get('adminPwd', '') %}
{% set admin_db_name = m.get('adminDBName', 'admin') %}
{% set root_user     = m.get('rootUser', '') %}
{% set root_pwd      = m.get('rootPwd', '') %}
{% set main_db_name  = m.get('mainDBName', 'proj-dbv01') %}
{% set exec_file     = m.get('mongodbExecFile', '/opt/mongodb/bin/mongo') %}

# =====================================
# Get DB names (connect as admin user)
# Expected results:
#   MongoDB shell version: 2.6.5
#   connecting to: admin
#   [ "local", "proj-dbv01", "admin" ]
#
db-names:
  cmd.run:
    - name: {{ exec_file }} -u {{ admin_user }} -p {{ admin_pwd }} {{ admin_db_name }} --eval "printjson(db.getMongo().getDBNames())"

# =====================================
# Get List of databases
# Expected results:
#   {
#      "databases" : [
#              {
#                      "name" : "local",
#                      "sizeOnDisk" : 1106771968,
#                      "empty" : false
#              },
#              {
#                      "name" : "proj-dbv01",
#                      "sizeOnDisk" : 33554432,
#                      "empty" : false
#              },
#              {
#                      "name" : "admin",
#                      "sizeOnDisk" : 33554432,
#                      "empty" : false
#              }
#      ],
#      "totalSize" : 1173880832,
#      "ok" : 1
#   }
#
list-databases:
  cmd.run:
    - name: {{ exec_file }} -u {{ admin_user }} -p {{ admin_pwd }} {{ admin_db_name }} --eval "printjson(db.runCommand({listDatabases:1}))"

# =====================================
# Get names of the collection in the main DB
# Expected results:
#   connecting to: proj-dbv01
#   [ "customers", "datacenters", "datapods", "system.indexes" ]
#
collection-names:
  cmd.run:
    - name: {{ exec_file }} -u {{ root_user }} -p {{ root_pwd }} {{ main_db_name }} --eval "printjson(db.getCollectionNames())"

# =====================================
# Validate "customers" collection in the main DB
# Expected results:
#   {
#      "ns" : "proj-dbv01.customers",
#      "firstExtent" : "0:48000 ns:proj-dbv01.customers",
#   . . .
#      "valid" : true,
#      "errors" : [ ],
#      "warning" : "Some checks omitted for speed. use {full:true} option to do more thorough scan.",
#      "ok" : 1
#
validate-cust-collection:
  cmd.run:
    - name: {{ exec_file }} -u {{ root_user }} -p {{ root_pwd }} {{ main_db_name }} --eval "printjson(db.customers.validate())"

# =====================================
# Get number of tables in the collection
# Expected results:
#
#
# num-tables-in-customers-coll:
#   cmd.run:
#    - name: {{ exec_file }} -u {{ admin_user }} -p {{ admin_pwd }} --eval "printjson(db.customers.count())"

