# =============================================================================
# ../pillar/cassandra/user/init.sls
# =============================================================================
cassandra_user:
  name: cassandra
  password: "$1$wH3KGjaw$xKkNsQUnG.bKS/HXS/vfv/"
  uid: 1002
  comment: "Cassandra User"
