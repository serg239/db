# =============================================================================
# cassandra/data/init.sls
# ============================================================================= 
# salt 'cas-node1' state.sls data saltenv=cassandra
# Test:
# $ /opt/cassandra/bin/cqlsh -u cassandra -p cassandra 10.9.60.71
# cassandra@cqlsh> select * from notifications.clientstatus;
# 
#  customerid | clienttype | clientid | username | attributes                                                                                         | cassandra_lucene_index | connectionstatus | laststatusupdatetime     | source
# ------------+------------+----------+----------+----------------------------------------------------------------------------------------------------+------------------------+------------------+--------------------------+--------
#           1 |       SITE |     1001 |          | {'clientSWVersion': '7.0', 'machineId': '1234567889', 'machineName': 'local', 'osInfo': 'Windows'} |                   null |        CONNECTED | 2015-12-04 00:11:32+0000 | manual
#           1 |       SITE |     1002 |          | {'clientSWVersion': '7.0', 'machineId': '1234567890', 'machineName': 'local', 'osInfo': 'Windows'} |                   null |     DISCONNECTED | 2015-12-04 00:16:20+0000 | manual
#           1 |       SITE |     1003 |          | {'clientSWVersion': '7.0', 'machineId': '1234567891', 'machineName': 'local', 'osInfo': 'Windows'} |                   null |     DISCONNECTED | 2015-12-04 00:18:07+0000 | manual
#           1 |       SITE |     1004 |          | {'clientSWVersion': '7.0', 'machineId': '1234567892', 'machineName': 'local', 'osInfo': 'Windows'} |                   null |     DISCONNECTED | 2015-12-04 00:18:39+0000 | manual
#  
# CQLSH:
insert-record-001:
  module.run:
    - name: cassandra_cql.cql_query
    - kwargs:
      query: "INSERT INTO notifications.clientstatus (customerid, clienttype, clientid, username, attributes, cassandra_lucene_index, connectionstatus, laststatusupdatetime, source) VALUES
              (1, 'SITE', '1001', '', {'clientSWVersion': '7.0', 'machineId': '1234567889', 'machineName': 'local', 'osInfo': 'Windows'}, null, 'CONNECTED', '2015-12-03 19:11:32', 'manual')"
      cql_user: 'cassandra'
      cql_pass: 'cassandra'
      port: 9042

insert-record-002:
  module.run:
    - name: cassandra_cql.cql_query
    - kwargs:
      query: "INSERT INTO notifications.clientstatus (customerid, clienttype, clientid, username, attributes, cassandra_lucene_index, connectionstatus, laststatusupdatetime, source) VALUES
              (1, 'SITE', '1002', '', {'clientSWVersion': '7.0', 'machineId': '1234567890', 'machineName': 'local', 'osInfo': 'Windows'}, null, 'DISCONNECTED', '2015-12-03 19:16:20', 'manual')"
      cql_user: 'cassandra'
      cql_pass: 'cassandra'
      port: 9042

insert-record-003:
  module.run:
    - name: cassandra_cql.cql_query
    - kwargs:
      query: "INSERT INTO notifications.clientstatus (customerid, clienttype, clientid, username, attributes, cassandra_lucene_index, connectionstatus, laststatusupdatetime, source) VALUES
              (1, 'SITE', '1003', '', {'clientSWVersion': '7.0', 'machineId': '1234567891', 'machineName': 'local', 'osInfo': 'Windows'}, null, 'DISCONNECTED', '2015-12-03 19:18:07', 'manual')"
      cql_user: 'cassandra'
      cql_pass: 'cassandra'
      port: 9042

insert-record-004:
  module.run:
    - name: cassandra_cql.cql_query
    - kwargs:
      query: "INSERT INTO notifications.clientstatus (customerid, clienttype, clientid, username, attributes, cassandra_lucene_index, connectionstatus, laststatusupdatetime, source) VALUES
              (1, 'SITE', '1004', '', {'clientSWVersion': '7.0', 'machineId': '1234567892', 'machineName': 'local', 'osInfo': 'Windows'}, null, 'DISCONNECTED', '2015-12-03 19:18:39', 'manual')"
      cql_user: 'cassandra'
      cql_pass: 'cassandra'
      port: 9042
