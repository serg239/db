# =========================================================
# Script:
#  /srv/salt/ns/orch/cassandra_start_seed_nodes.sls
# Usage:
#  salt-run state.orchestrate orch.cassandra_start_seed_nodes saltenv=ns
# =========================================================
{% from 'common_settings.sls' import stack_name %}
{% from 'common_settings.sls' import cc_role %}
{% from 'common_settings.sls' import cc_host_name_prefix %}
{% from 'common_settings.sls' import cc_num_seed_nodes %}

{% set cc_host_name_suffix = 's-*' %}
{% set timeout = 60 %}

{% set target = 'G@role:' ~ cc_role ~ ' and G@stack_name:' ~ stack_name ~ ' and G@nodename:' ~ cc_host_name_prefix ~ cc_host_name_suffix %}

# =========================================================
# Start seed nodes first
#
{% for idx in range(cc_num_seed_nodes) %}
seed-start-node-{{ idx }}:
  salt.state:
    - tgt: '{{ target }}{{ idx }}'
    - tgt_type: compound
    - sls: start
{% if idx > 0 %}
  {% set prev_idx = idx - 1 %}
    - require:
      - module: seed-start-sleep-{{ prev_idx }}
{% endif%}
seed-start-sleep-{{ idx }}:
  module.run:
    - name: test.sleep
    - length: {{ timeout }}
    - require:
      - salt: seed-start-node-{{ idx }}
{% endfor %}
