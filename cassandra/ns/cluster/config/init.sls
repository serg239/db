# ==============================================================
# Script:
#  /srv/salt/ns/cassandra/cluster/config/init.sls
# Description:
#   Set configuration parameters in the cassandra.yaml file on the node(s)
# Usage:
#   salt 'ccdc1*' -l debug state.sls cluster.config saltenv=ns
# ==============================================================

# Get cluster_name, endpoint_snitch from pillars
# Get list of seed IPs from the mine function
{% from 'cassandra/cluster/config/settings.sls' import config as c with context %}

#
# Static values from grains on the proxy-minion
#
{% set g = salt['grains.get']('cluster', {}) %}
{% set listen_address = g.get('private_ip', 'localhost') %}
{% set rpc_address = g.get('private_ip', 'localhost') %}

#
# Save cassandra config values in the ConfD DB
#
set-config-parameters:
  module.run:
    - name: coe.invoke_confd_cli
    - uri: /api/config/coe-services/cassandra/
    - method: PATCH
    - username: admin
    - password: admin
    - headers: True
    - text: True
    - input_xml: |
        <cassandra>
           <cluster-name>{{ c.cluster_name }}</cluster-name>
           <listen-address>{{ listen_address }}</listen-address>
           <rpc-address>{{ rpc_address }}</rpc-address>
           {% for seed in c.seeds %}<seeds>{{ seed }}</seeds>{% endfor %}
           <endpoint-snitch>{{ c.endpoint_snitch }}</endpoint-snitch>
        </cassandra>

#
# Upload values from ConfD DB to cassandra.yaml file on proxy-minion
#
upload-to-cassandra-yaml:
  module.run:
    - name: coe.invoke_confd_cli
    - uri: api/config/coe-services/cassandra/_operations/reload
    - method: POST
    - username: admin
    - password: admin
    - headers: True
    - text: True
    - header_list: ['Content-Type: application/vnd.yang.data+xml']
    - require:
      - module: set-config-parameters
