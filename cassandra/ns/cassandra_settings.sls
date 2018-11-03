# ==============================================================
# Script:
#   /srv/salt/ns/cassandra_settings.sls
# Description:
#   Auxiliary script. Prepares configuration parameters for cassandra.yaml
# Structure:
#   cassandra:
#     deployment
#     cluster_name
#     endpoint_snitch
#     first_ip
#     node_count
#     config:
#       seeds {}
#       regulars {}
#       nodes {}
# Usage:
#   from 'cassandra_settings.sls' import cassandra as c with context
# Examples:
#   c.config.cluster_name   - string
#   c.config.seeds          - dictionary
# Usage:
#   from 'cassandra_settings.sls' import config as conf with context
# Examples:
#   conf.cluster_name   - string
#   conf.seeds          - dictionary
# ==============================================================
{% from 'common_settings.sls' import stack_name %}

{% from 'common_settings.sls' import cc_role %}

{% from 'common_settings.sls' import cc_deployment %}
{% from 'common_settings.sls' import cc_cluster_name %}
{% from 'common_settings.sls' import cc_endpoint_snitch %}

#
# Default configuration values (cassandra.yaml) as dict
#
{% set default_config = {
  'deployment': cc_deployment,
  'cluster_name': cc_cluster_name,
  'endpoint_snitch': cc_endpoint_snitch,
  'seeds': salt['grains.get']('seeds', '127.0.0.1'),
	'regulars': salt['grains.get']('regulars', '127.0.0.1'),
  'nodes': salt['grains.get']('nodes', '127.0.0.1')
  }%}

#
# Create the configuration dictionary
#
{% set config = default_config %}
 
#
# Force update mines
#
{% set force_mine_update = salt['mine.send']('get_privateip') %}

#
# Lists of IPs of SEED cassandra DB nodes
#
{% set cassandra_seeds_dict = {} %}
{% set cassandra_seeds_dict = salt['mine.get']('G@role:' + cc_role + ' and G@stack_name:' + stack_name + ' and G@node_type:seed', 'get_privateip', 'compound') %}
{% set cassandra_seeds = cassandra_seeds_dict.values() %}
{% do cassandra_seeds.sort() %}
{% do config.update({'seeds':cassandra_seeds}) %}

{% set first_ip = cassandra_seeds[0] %}

#
# Lists of IPs of REGULAR cassandra DB nodes
#
{% set cassandra_regs_dict = {} %}
{% set cassandra_regs_dict = salt['mine.get']('G@role:' + cc_role + ' and G@stack_name:' + stack_name + ' and G@node_type:regular', 'get_privateip', 'compound') %}
{% set cassandra_regs = cassandra_regs_dict.values() %}
{% do cassandra_regs.sort() %}
{% do config.update({'regulars':cassandra_regs}) %}

#
# Lists of IDs and Host IPs of ALL cassandra DB nodes
#
{% set cassandra_host_dict = {} %}
{% set cassandra_host_dict = salt['mine.get']('G@role:' + cc_role + ' and G@stack_name:' + stack_name, 'get_privateip', 'compound') %}
{# set cassandra_host_dict = salt['mine.get']('G@role:' + cc_role, 'get_privateip', 'compound') #}
{% set cassandra_ips = cassandra_host_dict.values() %}
{% do cassandra_ips.sort() %}
{% do config.update({'nodes':cassandra_ips}) %}

{% set node_count = cassandra_ips | length() %}

#
# Cassandra dictionary
#
{% set cassandra = {} %}
{% do cassandra.update({
   'first_ip' : first_ip,
   'node_count' : node_count,
   'config': config
   }) %}
 