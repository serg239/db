# =============================================================================
# ../pillar/ns/cassandra/database/init.sls
# =============================================================================
db_conn:
  user_name: 'cassandra'
  password: 'cassandra'
  port_num: 9042
  comment: "Cassandra database credentials"

db_owner:
  user_name: 'ops'
  password: 'ops'

ks_replication:
# replication_strategy: 'SimpleStrategy'
  replication_strategy: 'NetworkTopologyStrategy'
  replication_datacenters: "dc1: 1"
  replication_factor: 2
