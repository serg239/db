# =============================================================================
# cassandra/remove_plugin/init.sls
# =============================================================================
#
# Remove Lucene Index plugin file
# cassandra-lucene-index-plugin-2.2.3.0.jar
# from /opt/cassandra/lib ($CASSANDRA_HOME) directory
#
remove-plugin-file:
  module.run:
    - name: sh_utils.remove_file
    - kwargs:
      file_full_name: "/opt/cassandra/lib/cassandra-lucene-index-plugin-2.2.3.0.jar"
