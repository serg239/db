-- ============================================================================
# /srv/salt/cassandra/top.sls
-- ============================================================================
cassandra:
  'cas-node*':
    - ntp
    - group
    - user
    - iptables
    - plugin
    - driver
    - tune
    - database
    - data
  'cas-node0':
#   - match: list
    - opscenter    
#   - hostconfig
