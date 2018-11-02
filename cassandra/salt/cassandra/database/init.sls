# =============================================================================
# database/init.sls
# =============================================================================
{% from 'node/settings.sls' import config as c with context %}

# salt 'cas-node1' state.sls database saltenv=cassandra
# CQLSH: CREATE USER 'ops' WITH PASSWORD 'ops';
# Test: LIST users;
create-user:
  module.run:
    - name: cassandra_cql.create_user
    - kwargs:
      username: {{ pillar['db_owner']['user_name'] }}
      password: {{ pillar['db_owner']['password'] }}
      superuser: False
      contact_points: {{ c.nodes }}
      cql_user: {{ pillar['db_conn']['user_name'] }}
      cql_pass: {{ pillar['db_conn']['password'] }}
      port: {{ pillar['db_conn']['port_num'] }}

# CQLSH: GRANT ALL ON ALL KEYSPACES TO ops;
# Test:
grant-permission:
  module.run:
    - name: cassandra_cql.grant_permission
    - kwargs:
      username: {{ pillar['db_owner']['user_name'] }}
#     resource: None             # permissions for all resources are granted
      resource_type: 'keyspace'
      permission: 'all'          # all permissions are granted
      contact_points: {{ c.nodes }}
      cql_user: {{ pillar['db_conn']['user_name'] }}
      cql_pass: {{ pillar['db_conn']['password'] }}
      port: {{ pillar['db_conn']['port_num'] }}
		- require:
      - module: create-user

# CQLSH: CREATE KEYSPACE IF NOT EXISTS notifications
# WITH REPLICATION = {'class': 'NetworkTopologyStrategy', 'dc1': 1}
# AND DURABLE_WRITES = true;
# Strategy: Simple  -> replication_factor
# Strategy: Network -> replication_datacenters
# Test: DESC keyspaces;
create-keyspace:
  module.run:
    - name: cassandra_cql.create_keyspace
    - kwargs:
      keyspace: 'notifications'
      replication_strategy: {{ repl_strategy }}
{% if repl_strategy == 'SimpleStrategy' %}
      replication_factor: {{ pillar['ks_replication']['replication_factor'] }}
{% else %}
      replication_datacenters: {{ pillar['ks_replication']['replication_datacenters'] }}
{% endif %}
      contact_points: {{ c.nodes }}
      cql_user: {{ pillar['db_conn']['user_name'] }}
      cql_pass: {{ pillar['db_conn']['password'] }}
      port: {{ pillar['db_conn']['port_num'] }}
			
# CQLSH:
# Test: DESC notifications.clientstatus;
create-table:
  module.run:
    - name: cassandra_cql.cql_query
    - kwargs:
      query: "CREATE TABLE IF NOT EXISTS notifications.clientstatus (
                customerid             INT,
                clienttype             TEXT,
                clientid               TEXT,
                username               TEXT,
                attributes             MAP<TEXT, TEXT>,
                cassandra_lucene_index TEXT,
                connectionstatus       TEXT,
                laststatusupdatetime   TIMESTAMP,
                source                 TEXT,
                PRIMARY KEY ((customerid, clienttype), clientid, username)
             ) WITH CLUSTERING ORDER BY (clientid ASC, username ASC)"
      contact_points: {{ c.nodes }}
      cql_user: {{ pillar['db_conn']['user_name'] }}
      cql_pass: {{ pillar['db_conn']['password'] }}
      port: {{ pillar['db_conn']['port_num'] }}
    - require:
      - module: create-keyspace

# CQLSH: CREATE CUSTOM INDEX IF NOT EXISTS clientstatus_lucene_idx
create-index:
  module.run:
    - name: cassandra_cql.cql_query
    - kwargs:
      query: "CREATE CUSTOM INDEX IF NOT EXISTS clientstatus_lucene_idx
              ON notifications.clientstatus (cassandra_lucene_index)
              USING 'com.stratio.cassandra.lucene.Index'
              WITH OPTIONS = {
                'refresh_seconds' : '10',
                'schema' : '{
                  fields : {
                    clientid : {type : \"text\"},
                    username : {type : \"text\"},
                    connectionstatus : {type : \"text\"},
                    laststatusupdatetime : {type : \"date\"}
                  }
                }'
              };"
      contact_points: {{ c.nodes }}
      cql_user: {{ pillar['db_conn']['user_name'] }}
      cql_pass: {{ pillar['db_conn']['password'] }}
      port: {{ pillar['db_conn']['port_num'] }}
	- require:
      - module: create-table

# CQLSH:
# Test: SELECT * FROM notifications.clientstatus;

# Test:
# get_keyspaces:
#  module.run:
#    - name: cassandra_cql.cql_query
#    - kwargs:
#      query: 'SELECT * FROM system.schema_keyspaces'
#      contact_points: {{ c.nodes }}
#      cql_user: {{ pillar['db_conn']['user_name'] }}
#      cql_pass: {{ pillar['db_conn']['password'] }}
#      port: {{ pillar['db_conn']['port_num'] }}
