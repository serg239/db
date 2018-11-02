# =============================================================================
# ../pillar/cassandra/opscenter/init.sls
# =============================================================================

opscenter:
  package_name: opscenter
  version: 5.2.2
  home_dir: /opt/opscenter
  conf_dir: /etc/opscenter
  port: 8888
  interface: 0.0.0.0
