-- ============================================================================
# /srv/salt/cassandra/top.sls
-- ============================================================================
cassandra:
  'cas-node*':
    - ntp
    - iptables
    - group
    - user
    - seed
    - node
    - plugin
    - driver
    - tune
    - database
    - data
  'cas-node0':
    - opscenter    
