# =============================================================================
# cassandra/plugin/init.sls
# =============================================================================
{% set dst_path = '/opt/cassandra/lib' %}
{% set plugin_name = pillar['plugin']['plugin_name'] + '-' + pillar['plugin']['version'] + '.jar'%}

lucene_plugin:
  file.managed:
    - name: {{ dst_path }}/{{ plugin_name }}
    - user: root
    - group: root
    - mode: 644
    - source: salt://cassandra/files/{{ plugin_name }}
    - check_run: test -e {{ dst_path }}/{{ plugin_name }}
