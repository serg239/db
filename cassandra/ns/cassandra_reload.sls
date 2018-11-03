coe:
  module.run:
     - name: coe.invoke_confd_cli
     - uri: api/config/coe-services/cassandra/_operations/reload
     - method: POST
     - username: admin
     - password: admin
     - header_list: ['Content-Type: application/vnd.yang.data+xml' ]
     - headers: True 
     - text: True
