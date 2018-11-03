coe:
  module.run:
     - name: coe.invoke_confd_cli
     - uri: api/config/coe-services/cassandra
     - method: GET
     - username: admin
     - password: admin
     - headers: True
     - text: True

