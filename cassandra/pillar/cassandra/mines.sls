# =============================================================================
# ../pillar/cassandra/mines.sls
# =============================================================================
mine_functions:
  grains.item: [fqdn_ip4]
  network.ip_addrs: [eth0]    