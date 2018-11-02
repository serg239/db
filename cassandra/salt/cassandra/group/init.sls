# =============================================================================
# group/init.sls
# =============================================================================
cassandra-group:
  group.present:
    - name: {{ pillar['cassandra_group']['name'] }}
    - gid: {{ pillar['cassandra_group']['gid'] }}
    - system: {{ pillar['cassandra_group']['system'] }}
