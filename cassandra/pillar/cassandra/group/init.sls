# =============================================================================
# ../pillar/cassandra/group/init.sls
# =============================================================================
cassandra_group:
  name: cassandra
  gid: 1002
  system: True
  comment: "Cassandra Group"
  