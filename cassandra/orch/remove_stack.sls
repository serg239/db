# =============================================================================
# orch/remove_stack.sls
# Usage:
#   salt-run state.orchestrate -l debug orch.remove_stack saltenv=cassandra
# =============================================================================
{% set cas_role = 'cassandra' %}

remove-database:
  salt.state:
    - tgt: 'G@roles:database'
    - tgt_type: grain
    - sls: remove_database

remove-opscenter:
  salt.state:
    - tgt: 'G@roles:database and G@node_type:opscenter'
    - tgt_type: compound
    - sls: remove_opscenter
    - require:
      - salt: remove-database

remove-plugin:
  salt.state:
    - tgt: 'G@roles:database'
    - tgt_type: grain
    - sls: remove_plugin
    - require:
      - salt: remove-database

remove-driver:
  salt.state:
    - tgt: 'G@roles:database'
    - tgt_type: grain
    - sls: remove_driver
    - require:
      - salt: remove-database
			
remove-node:
  salt.state:
    - tgt: 'G@roles:database and G@node_type:regular'
    - tgt_type: compound
    - sls: remove_node
    - require:
      - salt: remove-database

remove-seed:
  salt.state:
    - tgt: 'G@roles:database and G@node_type:seed'
    - tgt_type: compound
    - sls: remove_seed
    - require:
      - salt: remove-node

remove-user:
  salt.state:
    - tgt: 'G@roles:{{ cas_role }}'
    - tgt_type: grain
    - sls: remove_user
    - require:
      - salt: remove-seed

remove-group:
  salt.state:
    - tgt: 'G@roles:{{ cas_role }}'
    - tgt_type: grain
    - sls: remove_group
    - require:
      - salt: remove-user

# remove-tune:
#   salt.state:
#     - tgt: 'G@roles:database'
#     - tgt_type: grain
#     - sls: remove_tune
#     - require:
#       - salt: remove-node

remove-iptables:
  salt.state:
    - tgt: 'G@roles:{{ cas_role }}'
    - tgt_type: grain
    - sls: remove_iptables
    - require:
      - salt: remove-group

remove-ntp:
  salt.state:
    - tgt: 'G@roles:{{ cas_role }}'
    - tgt_type: grain
    - sls: remove_ntp
    - require:
      - salt: remove-group
			