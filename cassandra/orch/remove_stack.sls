{% set cas_role = 'G@roles:cassandra and G@roles:database' %}

remove-database:
  salt.state:
    - tgt: '{{ cas_role }} and G@roles:opscenter'
    - tgt_type: compound
    - sls: remove_database

remove-opscenter:
  salt.state:
    - tgt: '{{ cas_role }} and G@roles:opscenter'
    - tgt_type: compound
    - sls: remove_opscenter
    - require:
      - salt: remove-database

remove-plugin:
  salt.state:
    - tgt: {{ cas_role }}
    - tgt_type: compound
    - sls: remove_plugin
    - require:
      - salt: remove-database

remove-driver:
  salt.state:
    - tgt: {{ cas_role }}
    - tgt_type: compound
    - sls: remove_driver
    - require:
      - salt: remove-database

remove-node:
  salt.state:
    - tgt: '{{ cas_role }} and G@node_type:regular'
    - tgt_type: compound
    - sls: remove_node
    - require:
      - salt: remove-database

remove-seed:
  salt.state:
    - tgt: '{{ cas_role }} and G@node_type:seed'
    - tgt_type: compound
    - sls: remove_seed
    - require:
      - salt: remove-node

remove-user:
  salt.state:
    - tgt: '{{ cas_role }}'
    - tgt_type: compound
    - sls: remove_user
    - require:
      - salt: remove-seed

remove-group:
  salt.state:
    - tgt: '{{ cas_role }}'
    - tgt_type: compound
    - sls: remove_group
    - require:
      - salt: remove-user

# remove-tune:
#   salt.state:
#     - tgt: 'G@roles:database'
#     - tgt_type: compound
#     - sls: remove_tune
#     - require:
#       - salt: remove-node

remove-iptables:
  salt.state:
    - tgt: '{{ cas_role }}'
    - tgt_type: compound
    - sls: remove_iptables
    - require:
      - salt: remove-group

remove-ntp:
  salt.state:
    - tgt: '{{ cas_role }}'
    - tgt_type: compound
    - sls: remove_ntp
    - require:
      - salt: remove-group

