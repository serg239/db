# =============================================================================
#  opscenter/init.sls
# =============================================================================
#
# Install, Configure, and Run the DataStax OpsCenter -
# web-based visual management and monitoring solution
# for Apache Cassandra
#
{% set version = pillar['opscenter']['version'] %}
{% set home_dir = pillar['opscenter']['home_dir'] %}
{% set conf_dir = pillar['opscenter']['conf_dir'] %}

opscenter-tool:
  archive.extracted:
    - name: /opt/
    - source: http://downloads.datastax.com/community/opscenter.tar.gz
    - source_hash: md5=11c5614e08a30ac7f355b941240d229f
    - archive_format: tar
    - tar_options: xz
    - if_missing: {{ home_dir }}

#
# Copy updated from pillar configuration file
#
opscenter-configuration:
  file.managed:
    - name: {{ conf_dir }}/opscenterd.conf
    - makedirs: True
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - source: salt://files/opscenterd.conf.jinja
    - template: jinja
    - require:
      - archive: opscenter-tool

#
# Create symb link to the home directory
#
{% if 1 == salt['cmd.retcode']('test -f home_dir') %}
{{ home_dir }}:
  file.symlink:
    - target: {{ home_dir }}-{{ version }}
    - watch:
      - file: opscenter_configuration
{% endif %}

#
# Update the PATH env. variable
#
{% set current_path = salt['environ.get']('PATH', '/bin:/usr/bin') %}

#
# Run the opscenter process
#
opscenter:
  cmd.run:
    - name: opscenter
    - user: root
    - group: root
    - env:
        - PATH: {{ [current_path, home_dir ~ '/bin']|join(':') }}
    - require:
      - archive: opscenter-tool

#
# Run the opscenter service
#
# opscenterd:
#  service:
#    - running
#    - require:
#      - file: opscenter-configuration
