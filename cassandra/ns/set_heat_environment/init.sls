# =============================================================================
# State:
#   /srv/salt/dev/ns/set_heat_environment/init.sls
# Description:
#   Manage the file by the salt master and run it through templating system.
# Usage:
#   salt 'ops' state.sls ns.set_heat_environment saltenv=dev
# =============================================================================
{% set po = salt['pillar.get']('ops', {}) %}
{% set stack_name  = po.get('stack_name', 'unknown') %}
{% set data_center = po.get('data_center', 'unknown') %}
{% set path='/etc/heat/templates/' ~ stack_name ~ '-' ~ data_center ~ '-ns-environment.yaml' %}

heat_environment:
  file.managed:
    - name: {{ path }}
    - user: root
    - group: root
    - mode: 644
    - source: salt://ns/files/{{ stack_name }}-{{ data_center }}-ns-environment.jinja
    - template: jinja
