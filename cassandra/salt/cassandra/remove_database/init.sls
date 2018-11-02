# =============================================================================
# cassandra/remove_database/init.sls
# =============================================================================
#
# Drop cassandra database objects:
# * lucene index
# * clientstatus table
# * notifications keyspace
#
{% from 'cassandra/node/settings.sls' import config as c with context %}

# CQLSH: DROP INDEX IF EXISTS notifications.clientstatus_lucene_idx
# drop-index:
#  module.run:
#    - name: cassandra_cql.cql_query
#    - kwargs:
#      query: "DROP INDEX IF EXISTS notifications.clientstatus_lucene_idx;"
#      contact_points: {{ c.nodes }}
#      cql_user: {{ pillar['db_conn']['user_name'] }}
#      cql_pass: {{ pillar['db_conn']['password'] }}
#      port: {{ pillar['db_conn']['port_num'] }}


# CQLSH: DROP TABLE IF EXISTS notifications.clientstatus
# Test: DESC notifications.clientstatus;
drop-table:
  module.run:
    - name: cassandra_cql.cql_query
    - kwargs:
      query: "DROP TABLE IF EXISTS notifications.clientstatus;"
      contact_points: {{ c.nodes }}
      cql_user: {{ pillar['db_conn']['user_name'] }}
      cql_pass: {{ pillar['db_conn']['password'] }}
      port: {{ pillar['db_conn']['port_num'] }}
#   - watch:
#      - module: drop-index

# CQLSH: DROP KEYSPACE IF EXISTS notifications
drop-keyspace:
  module.run:
    - name: cassandra_cql.drop_keyspace
    - kwargs:
      keyspace: 'notifications'
      contact_points: {{ c.nodes }}
      cql_user: {{ pillar['db_conn']['user_name'] }}
      cql_pass: {{ pillar['db_conn']['password'] }}
      port: {{ pillar['db_conn']['port_num'] }}
    - watch:
      - module: drop-table

# =============================================================================
# TEST:
# /opt/cassandra/bin/cqlsh -u cassandra -p cassandra 10.9.60.71
# =============================================================================
# before: 
# cassandra@cqlsh> desc keyspaces;
# system_auth  "OpsCenter"    system_distributed
# system       notifications  system_traces

# after:
# cassandra@cqlsh> desc keyspaces;
# system_traces  system_auth  system  "OpsCenter"  system_distributed
