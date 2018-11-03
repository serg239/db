# ==============================================================
# Script:
#   /srv/salt/ns/cassandra/cluster/config/settings.sls
# Description:
#   Auxiliary script. Prepares configuration parameters for cassandra.yaml
# Usage:
#   from 'cassandra/cluster/config/settings.sls' import cassandra as c with context
# Examples:
#   c.config.cluster_name   - string
#   c.config.seeds          - dictionary
# Usage:
#   from 'cassandra/cluster/config/settings.sls' import config as conf with context
# Examples:
#   conf.cluster_name   - string
#   conf.seeds          - dictionary
# Note:
#   Merge pillars in the /srv/salt/pillar/ns/top.sls
#   base
#     . . .
#     'ccdc1*':
#       - ns.cassandra.mines
#       - ns.cassandra.cluster
# ==============================================================
#
# Get available values from Pillar
#
{% set p  = salt['pillar.get']('cluster', {}) %}
{% set pc = p.get('config', {}) %}
#
# Get available values from Grains
#
{% set g  = salt['grains.get']('cluster', {}) %}
{% set gc = g.get('config', {}) %}
#
# Default cluster values
#
{% set cassandra_instances = p.get('ops_cassandra_instances', '') %}

#
# Default configuration values (cassandra.yaml) as dict
#
{% set default_config = {
  'deployment': 'dc',
  'cluster_name': 'notifications',
  'endpoint_snitch': 'SimpleSnitch',
  'seeds': gc.get('seeds', '127.0.0.1'),
  'nodes': gc.get('nodes', '127.0.0.1')
  }%}

#
# Create the configuration dictionary
#
{% set config = default_config %}

# Update the default configuration values from Pillar
{% do config.update(pc) %}
{% do config.update(gc) %}

#
# Force update mines
#
{% set force_mine_update = salt['mine.send']('cassandra_private_ips') %}

#
# Generate an ordered list of cassandra seed IPs
#
{% set cassandra_seeds_dict = salt['mine.get']('G@cluster:roles:database and G@cluster:node_type:seed', 'cassandra_private_ips', 'compound') %}
{% set cassandra_seeds = cassandra_seeds_dict.values() %}
{% do cassandra_seeds.sort() %}
{% do config.update({'seeds':cassandra_seeds}) %}

#
# Generate an ordered list of IPs of all cassandra DB nodes
#
{% set cassandra_host_dict = salt['mine.get']('G@cluster:roles:database', 'cassandra_private_ips', 'grain') %}
{% set cassandra_hosts = cassandra_host_dict.values() %}
{% do cassandra_hosts.sort() %}
{% do config.update({'nodes':cassandra_hosts}) %}

#
# Cassandra dictionary
#
{% set cassandra = {} %}

{% do cassandra.update({
  'cassandra_instances': cassandra_instances,
  'config': config
  }) %}
  