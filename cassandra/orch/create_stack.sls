{% set cas_role = 'G@roles:cassandra and G@roles:database' %}

deploy-ntp:
  salt.state:
    - tgt: {{ cas_role }}
    - tgt_type: compound
    - sls: ntp

deploy-iptables:
  salt.state:
    - tgt: {{ cas_role }}
    - tgt_type: compound
    - sls: iptables

deploy-group:
  salt.state:
    - tgt: {{ cas_role }}
    - tgt_type: compound
    - sls: group

deploy-user:
  salt.state:
    - tgt: {{ cas_role }}
    - tgt_type: compound
    - sls: user
    - require:
      - salt: deploy-group

deploy-seed-node:
  salt.state:
    - tgt: '{{cas_role }} and G@node_type:seed'
    - tgt_type: compound
    - sls: seed
    - require:
      - salt: deploy-user

deploy-regular-node:
  salt.state:
    - tgt: '{{cas_role }} and G@node_type:regular'
    - tgt_type: compound
    - sls: node
    - require:
      - salt: deploy-seed-node

deploy-plugin:
  salt.state:
    - tgt: {{ cas_role }}
    - tgt_type: compound
    - sls: plugin
    - require:
      - salt: deploy-regular-node

deploy-driver:
  salt.state:
    - tgt: {{ cas_role }}
    - tgt_type: compound
    - sls: driver
    - require:
      - salt: deploy-regular-node

# deploy-tune:
#   salt.state:
#     - tgt: {{ cas_role }}
#     - tgt_type: compound
#     - sls: tune
#     - require:
#       - salt: deploy-regular-node

deploy-database:
  salt.state:
    - tgt: '{{ cas_role }} and G@roles:opscenter'
    - tgt_type: compound
    - sls: database
    - require:
      - salt: deploy-driver

deploy-data:
  salt.state:
    - tgt: '{{ cas_role }} and G@roles:opscenter'
    - tgt_type: compound
    - sls: data
    - require:
      - salt: deploy-database

deploy-opscenter:
  salt.state:
    - tgt: '{{ cas_role }} and G@roles:opscenter'
    - tgt_type: compound
    - sls: opscenter
    - require:
      - salt: deploy-regular-node

