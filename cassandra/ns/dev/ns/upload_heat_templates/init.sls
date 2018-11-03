# =============================================================================
# State:
#   /srv/salt/dev/ns/upload_heat_templates/init.sls
# Description:
#   Upload Heat template files to OpenStack
# Usage:
#   salt 'ops' -l debug state.sls ns.upload_heat_templates saltenv=dev
# =============================================================================
{% set po = salt['pillar.get']('ops', {}) %}
{% set stack_name  = po.get('stack_name', 'unknown') %}
{% set data_center = po.get('data_center', 'unknown') %}
{% set dst_path = '/etc/heat/templates/' %}

{% set zkc_path     = dst_path ~ 'zookeeper-instance.yaml' %}
{% set kc_path      = dst_path ~ 'kafka-instance.yaml' %}
{% set cc_path      = dst_path ~ 'cassandra-instance.yaml' %}
{% set ns_path      = dst_path ~ 'ns-instance.yaml' %}

{% set ns_full_path = dst_path ~ stack_name ~ '-' ~ data_center ~ '-ns-full.yaml' %}

{{ zkc_path }}:
  file.managed:
    - source: salt://ns/files/zookeeper-instance.yaml
    - user: root
    - group: root
    - mode: 644

{{ kc_path }}:
  file.managed:
    - source: salt://ns/files/kafka-instance.yaml
    - user: root
    - group: root
    - mode: 644

{{ cc_path }}:
  file.managed:
    - source: salt://ns/files/cassandra-instance.yaml
    - user: root
    - group: root
    - mode: 644

{{ ns_path }}:
  file.managed:
    - source: salt://ns/files/ns-instance.yaml
    - user: root
    - group: root
    - mode: 644

{{ ns_full_path }}:
  file.managed:
    - source: salt://ns/files/{{ stack_name }}-{{ data_center }}-ns-full.yaml
    - user: root
    - group: root
    - mode: 644
    