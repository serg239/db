# =============================================================================
# remove_group/init.sls
# =============================================================================
#
# Drop the Cassandra Group
#
remove-group:
  group.absent:
    - name: {{ pillar['cassandra_group']['name'] }}
