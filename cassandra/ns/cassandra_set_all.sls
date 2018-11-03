# ==============================================================
# Script:
#   /srv/salt/ns/casandra_set_all.sls
# Description:
#   Configure cassandra.yaml files on all cassandra cluster nodes
# Usage:
#   salt 'cc*' state.sls cassandra_set_all saltenv=ns
# ==============================================================
{% from 'cassandra_settings.sls' import config as c with context %}

{% set listen_address = salt['grains.get']('private_ip', 'localhost') %}
{% set rpc_address = salt['grains.get']('private_ip', 'localhost') %}

#
# Clear seed node IP values from ConfD DB
#
clear_seeds:
  module.run:
     - name: coe.invoke_confd_cli
     - uri: api/config/coe-services/cassandra/seeds
     - method: DELETE
     - username: admin
     - password: admin
     - header_list: ['Accept: */*']
     - headers: True
     - text: True

#
# Save cassandra config values in the ConfD DB
#
set-config-parameters:
  module.run:
     - name: coe.invoke_confd_cli
     - uri: api/config/coe-services/cassandra
     - method: PATCH
     - username: admin
     - password: admin
     - headers: True
     - text: True
     - input_xml:
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
