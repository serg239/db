# =============================================================================
# State:
#   /srv/salt/ns/cassandra_upload_rackdc.sls
# Description:
#   Upload cassandra_rackdc.properties file to cassandra nodes
# Usage:
#   salt 'dev-dc1-*' -l debug state.sls cassandra_upload_rackdc pillar='{"dc": "dc1"}' saltenv=ns
#   salt 'dev-dc2-*' -l debug state.sls cassandra_upload_rackdc pillar='{"dc": "dc2"}' saltenv=ns
# =============================================================================
{% set dc_name  = pillar['dc'] %}

{% set dst_path = '/etc/cassandra/conf/' %}
{% set rackdc_path = dst_path ~ 'cassandra-rackdc.properties' %}

{{ rackdc_path }}:
  file.managed:
    - source: salt://files/cassandra-rackdc.jinja
    - user: cassandra
    - group: cassandra
    - mode: 644
    - template: jinja
