# =========================================================
# Script:
#   /srv/salt/ns/orch/deploy_cc_database.sls
# Usage:
#   salt-run state.orchestrate orch.deploy_cc_database saltenv=ns
# =========================================================
{% set cc_role = 'G@cluster:roles:cassandra and G@cluster:roles:database' %}

{% set p  = salt['pillar.get']('cluster', {}) %}
{% set cluster_name = p.get('cluster_name', 'cc') %}
{% set datacenter_name = p.get('datacenter_name', 'dc1') %}
{% set target = cluster_name ~ datacenter_name ~ '*' %}

# =========================================================
# Update configuration parameters in cassandra.yaml
#
configure-instances:
  salt.state:
    - tgt: '{{ target }}'
    - sls: cluster.config

# =========================================================
# Start seed nodes first
#
start-seed-nodes:
  salt.state:
    - tgt: '{{cc_role }} and G@cluster:node_type:seed'
    - tgt_type: compound
    - sls: cluster.start
    - require:
      - salt: configure-instances

# =========================================================
# Initiate a 60 seconds delay
#
msg-seed-config:
  cmd.run:
    - name: echo "Waiting 60 sec after seed nodes start"
    - watch:
      - salt: start-seed-nodes

seed-config:
  module.run:
    - name: test.sleep
    - length: 60
    - require:
      - cmd: msg-seed-config

# =========================================================
# Start regular nodes after seed nodes
#
start-regular-nodes:
  salt.state:
    - tgt: '{{cc_role }} and G@cluster:node_type:regular'
    - tgt_type: compound
    - sls: cluster.start
    - require:
      - module: seed-config

# =========================================================
# Initiate a 60 seconds delay
#
msg-regular-config:
  cmd.run:
    - name: 'echo "Waiting 60 sec after regular nodes start"'
    - watch:
      - salt: start-regular-nodes

regular-config:
  module.run:
    - name: test.sleep
    - length: 60
    - require:
      - cmd: msg-regular-config

# =========================================================
# Create cassandra database (keyspace, tables, lucene index, ops user, etc.)
#
deploy-database:
  salt.state:
    - tgt: '{{ cc_role }} and G@cluster:roles:opscenter'
    - tgt_type: compound
    - sls: cluster.database
    - require:
      - module: regular-config

# =========================================================
# Insert test data
#
# insert-test-data:
#   salt.state:
#     - tgt: '{{ cc_role }} and G@roles:opscenter'
#     - tgt_type: compound
#     - sls: cluster.data
#     - require:
#       - salt: deploy-database
