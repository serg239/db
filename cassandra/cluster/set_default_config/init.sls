# ==============================================================
# Script:
#  /srv/salt/ns/cassandra/cluster/set_default_config/init.sls
# Description:
#   Set default configuration parameters in the cassandra.yaml file on the node(s)
# Usage:
#   salt 'nsccdc1*' -l debug state.sls cluster.set_default_config saltenv=ns
#   salt 'nsccdc1-01' -l debug state.sls cluster.set_default_config saltenv=ns
# ==============================================================
set-config-parameters:
  module.run:
     - name: coe.invoke_confd_cli
     - uri: /api/config/coe-services/cassandra/
     - method: PUT
     - username: admin
     - password: admin
     - headers: True
     - text: True
     - input_xml: |
          <cassandra>
            <cluster-name>notifications</cluster-name>
            <endpoint-snitch>SimpleSnitch</endpoint-snitch>
            <listen-address>localhost</listen-address>
            <rpc-address>localhost</rpc-address>
            <seeds>127.0.0.1</seeds>
          </cassandra>

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
