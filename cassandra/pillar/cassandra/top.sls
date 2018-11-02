# =============================================================================
# ../pillar/cassandra/top.sls
# =============================================================================
cassandra:
  'cas-node*':
    - mines
    - group
    - user
    - ports
    - node
    - opscenter
    - database
#   - tune
  
