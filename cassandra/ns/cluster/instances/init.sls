# =========================================================
# Script [master]:
#   /srv/salt/ns/cassandra/cluster/instances/init.sls
# Description:
#   Download and transform heat template
#   Create stack of the cassandra instances
# Usage:
#   > salt 'ops' -l debug state.sls cluster.instances saltenv=ns
# To delete stack:
#   > heat stack-delete nsccdc1
# Config pillars: /srv/salt/pillar/ns/top.sls:
#   base:
#     'ops':
#       - ns.cassandra.cluster
# Config states: /srv/salt/ns/top.sls:
#   ns:
#     'ops':
#       - cassandra.cluster
# =========================================================
# TOP sls: /srv/salt/ns/cassandra/top.sls
#   cassandra:
#    'nsccdc1*':
#      - cluster.instances
# =========================================================
{% set p  = salt['pillar.get']('cluster', {}) %}

{% set cluster_name = p.get('cluster_name', 'cc') %}
{% set datacenter_name = p.get('datacenter_name', 'dc1') %}
{% set owner_name = p.get('owner_name', 'sz') %}

{% set ops_source_file_name = p.get('ops_source_file_name', '~/keystonerc_debug') %}

gen-heat-template:
  file.managed:
    - name: /etc/heat/templates/cassandra-heat-template.yaml
    - user: root
    - group: root
    - mode: 644
    - source: salt://files/cassandra_heat_template.jinja
    - template: jinja

create-stack:
  cmd.run:
    - name: source {{ ops_source_file_name }} && heat stack-create -f /etc/heat/templates/cassandra-heat-template.yaml {{ cluster_name }}{{ datacenter_name }}-{{ owner_name }}
    - require:
      - file: gen-heat-template

# refresh-custom-grains:
#   module.run:
#     - name: saltutil.sync_all
#     - refresh: True
#     - watch:
#       - cmd: create-stack
