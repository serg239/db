# =============================================================================
# cassandra/node/settings.sls
# =============================================================================
#
# Get available values from Pillar
#
{% set p  = salt['pillar.get']('node', {}) %}
{% set pc = p.get('config', {}) %}

#
# Get available values from Grains
#
{% set g  = salt['grains.get']('cassandra', {}) %}
{% set gc = g.get('config', {}) %}

#
# Assign the cassandra's configuration values
#
{% set path_to_package = g.get('path_to_package', p.get('path_to_package', 'https://archive.apache.org/dist')) %}
{% set package_name    = g.get('package_name', p.get('package_name', 'cassandra')) %}
{% set version         = g.get('version', p.get('version', '2.2.3')) %}
{% set series          = g.get('series', p.get('series', '22x')) %}
{% set install_java    = g.get('install_java', p.get('install_java', False)) %}
{% set home_dir        = g.get('home_dir', p.get('home_dir', '/opt/apache-cassandra-' ~ version)) %}
{% set conf_dir        = g.get('conf_dir', p.get('conf_dir', '/opt/apache-cassandra-' ~ version ~ '/conf')) %}
{% set data_dir        = g.get('data_dir', p.get('data_dir', '/var/lib/cassandra/data')) %}
{% set auto_discovery  = g.get('auto_discovery', p.get('auto_discovery', False)) %}

#
# Config dictionary (cassandra.yaml)
#
# Defaul values
#
{% set default_config = {
  'cluster_name': 'notification-service',
  'home_dir': '/opt/apache-cassandra-' ~ version,
  'conf_dir': '/opt/apache-cassandra-' ~ version ~ '/conf',
  'data_dir': '/var/lib/cassandra/data',
  'data_file_directories': ['/var/lib/cassandra/data'],
  'commitlog_directory': '/var/lib/cassandra/commitlog',
  'saved_caches_directory': '/var/lib/cassandra/saved_caches',
  'seeds': gc.get('seeds', '127.0.0.1'),
  'nodes': gc.get('nodes', '127.0.0.1'),
  'endpoint_snitch': 'SimpleSnitch',
  'authenticator': 'AllowAllAuthenticator',
  'authorizer': 'AllowAllAuthorizer'
  }%}

#  'listen_address': 'localhost',
#  'rpc_address': 'localhost',

{%- set config = default_config %}

# Update the default values from Pillar and Grains
{% do config.update(pc) %}
{% do config.update(gc) %}

#
# auto_discovery -> generate an ordered list of Seed nodes (IPs)
#
{% if auto_discovery %}
{% set force_mine_update = salt['mine.send']('network.ip_addrs') %}
{% set cassandra_seeds_dict = salt['mine.get']('G@roles:database and G@node_type:seed', 'network.ip_addrs', 'compound') %}
{% set cassandra_seeds = cassandra_seeds_dict.values() %}
{% do cassandra_seeds.sort() %}
{% do config.update({'seeds':cassandra_seeds[:4]}) %}
{% endif %}

#
# Generate an ordered list of IPs of all cassandra DB nodes
#
{% set cassandra_host_dict = salt['mine.get']('G@role:database', 'network.ip_addrs', 'compound') %}
{% set cassandra_hosts = cassandra_host_dict.values() %}
{% do cassandra_hosts.sort() %}
{% do config.update({'nodes':cassandra_hosts[:4]}) %}

#
# Cassandra dictionary
#
{% set cassandra = {} %}

{% do cassandra.update({
  'path_to_package': path_to_package,
  'package_name': package_name,
  'version': version,
  'series': series,
  'install_java': install_java,
  'home_dir': home_dir,
  'conf_dir': conf_dir,
  'data_dir': data_dir,
  'config': config
   }) %}
