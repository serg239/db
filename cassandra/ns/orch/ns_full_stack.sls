{% from 'common_settings.sls' import data_center with context %}

zookeeper_config_and_start:
  salt.state:
    - tgt: 'zkc-{{ data_center }}-*'
    - sls: zookeeper_set_all

kafka_config_and_start:
  salt.state:
    - tgt: 'kc-{{ data_center }}-*'
    - sls: kafka_set_all

cassandra_config:
  salt.state:
    - tgt: 'cc[sr]-{{ data_center }}-*'
    - sls: cassandra_set_all
    - require:
      - salt: kafka_config_and_start

cassandra_start_seed_nodes:
  salt.state:
    - tgt: 'ccs-{{ data_center }}-*'
    - sls: cassandra_start
    - require:
      - salt: cassandra_config

sleep_after_seed_start:
  module.run:
    - name: test.sleep
    - length: 30
    - require:
      - salt: cassandra_start_seed_nodes

cassandra_start_regular_nodes:
  salt.state:
    - tgt: 'ccr-{{ data_center }}-*'
    - sls: cassandra_start

sleep_after_regular_start:
  module.run:
    - name: test.sleep
    - length: 30
    - require:
      - salt: cassandra_start_regular_nodes

cassandra_load_schema:
  salt.state:
    - tgt: 'ccs-{{ data_center }}-0'
    - sls: cassandra_load_schema

kafka_create_topic:
  salt.state:
    - tgt: 'kc-{{ data_center }}-0'
    - sls: kafka_create_topic_tmp

cassandra_ops_permission:
  salt.state:
    - tgt: 'ccs-{{ data_center }}-0'
    - sls: cassandra_ops_permission_tmp

ns_config:
  salt.state:
    - tgt: 'ns-{{ data_center }}-*'
    - sls: ns_set_all

ns_reload:
  salt.state:
     - tgt: 'ns-{{ data_center }}-*'
     - sls: ns_reload

ns_start:
  salt.state:
     - tgt: 'ns-{{ data_center }}-*'
     - sls: ns_restart
