# ==============================================================
# Script:
#  /srv/salt/ns/cassandra/cluster/set_default_config.sls
# Description:
#   Set default configuration on all nodes
# Usage:
#   salt 'nsccdc1*' state.sls cluster.set_default_config
# ==============================================================
set-default-cluster-name:
  module.run:
     - name: coe.invoke_confd_cli
     - uri: /api/config/coe-services/cassandra/
     - method: PUT
     - username: admin
     - password: admin
     - headers: True
     - text: True
     - input_xml: <cassandra><cluster-name>notifications</cluster-name></cassandra>

set-default-endpoint-snitch:
  module.run:
     - name: coe.invoke_confd_cli
     - uri: /api/config/coe-services/cassandra/
     - method: PUT
     - username: admin
     - password: admin
     - headers: True
     - text: True
     - input_xml: <cassandra><endpoint-snitch>SimpleSnitch</endpoint-snitch></cassandra>

set-default-listen-address:
  module.run:
     - name: coe.invoke_confd_cli
     - uri: /api/config/coe-services/cassandra/
     - method: PUT
     - username: admin
     - password: admin
     - headers: True
     - text: True
     - input_xml: <cassandra><listen-address>localhost</listen-address></cassandra>

set-default-rpc-address:
  module.run:
     - name: coe.invoke_confd_cli
     - uri: /api/config/coe-services/cassandra/
     - method: PUT
     - username: admin
     - password: admin
     - headers: True
     - text: True
     - input_xml: <cassandra><rpc-address>localhost</rpc-address></cassandra>

set-default-seeds:
  module.run:
     - name: coe.invoke_confd_cli
     - uri: /api/config/coe-services/cassandra/
     - method: PUT
     - username: admin
     - password: admin
     - headers: True
     - text: True
     - input_xml: <cassandra><seeds>127.0.0.1</seeds></cassandra>

reload-to-cassandra-yaml:
  module.run:
    - name: coe.invoke_confd_cli
    - uri: api/config/coe-services/cassandra/_operations/reload
    - method: POST
    - username: admin
    - password: admin
    - headers: True
    - text: True
    - header_list: ['Content-Type: application/vnd.yang.data+xml']

