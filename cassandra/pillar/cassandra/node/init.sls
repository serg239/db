# =============================================================================
# ../pillar/ns/cassandra/node/init.sls
# =============================================================================
node:
  path_to_package: https://repo1.maven.org/maven2/org/apache/cassandra
  package_name: apache-cassandra
  version: 2.2.3
  series: 22x
  install_java: True
  home_dir: /opt/cassandra
  conf_dir: /etc/cassandra
  data_dir: /srv/cassandra/data
  auto_discovery: True
  config:
    cluster_name: ns
    authenticator: PasswordAuthenticator
#   authenticator: AllowAllAuthenticator
    authorizer: CassandraAuthorizer
#   authorizer: AllowAllAuthorizer
    data_file_directories:
      - /srv/cassandra/data
    commitlog_directory: /srv/cassandra/commitlogs
    saved_caches_directory: /srv/cassandra/saved_caches
#   endpoint_snitch: SimpleSnitch
    endpoint_snitch: GossipingPropertyFileSnitch
  java_opts:
    xss: 280k
