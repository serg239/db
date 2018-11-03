# =========================================================
# Script:
#   /srv/salt/ns/orch/deploy_cc_cluster.sls
# Usage:
#   salt-run state.orchestrate orch.deploy_cc_cluster saltenv=ns
# =========================================================
{% set cc_role = 'G@cluster:roles:cassandra and G@cluster:roles:database' %}

{% set p  = salt['pillar.get']('cluster', {}) %}
{% set cluster_name = p.get('cluster_name', 'cc') %}
{% set datacenter_name = p.get('datacenter_name', 'dc1') %}
{% set target = cluster_name ~ datacenter_name ~ '*' %}

# =========================================================
# Remove cassandra stack from OpenStack heat
# Remove image from OpenStack glance
#
drop-stack:
  salt.state:
    - tgt: 'ops'
    - sls: cluster.drop_stack

# =========================================================
# Delete old minion keys from salt-master
#
delete-minion-keys:
  cmd.run:
    - name: salt-key -y -d {{ target }}
    - onlyif: test `salt-key | grep {{ target }} | wc -l` -gt 0
#   - onlyif: test `salt-key -l den | grep {{ target }} | wc -l` -gt 0

# =========================================================
# Upload image from buildarchive to OpenStack Glance
#
upload-image:
  salt.state:
    - tgt: 'ops'
    - sls: cluster.image

# =========================================================
# Create set of cassandra instances in OpenStack
#
deploy-instances:
  salt.state:
    - tgt: 'ops'
    - sls: cluster.instances
    - require:
      - salt: upload-image

# Takes a time....