# =============================================================================
# cassandra/node/init.sls
# =============================================================================
{% from 'cassandra/node/settings.sls' import cassandra with context %}

{% if cassandra.install_java %}
java-1.8.0-openjdk:
  pkg.installed:
    - require_in:
#     - pkg: cassandra_package
      - archive: cassandra-server
{% endif %}

# cassandra_package:
#   pkgrepo.managed:
#     - humanname: Cassandra Debian Repo
#     - name: deb http://debian.datastax.com/community stable main
#     - file: /etc/apt/sources.list.d/cassandra.sources.list
#     - key_url: http://debian.datastax.com/debian/repo_key
#   pkg.installed:
#     - name: {{ cassandra.package_name }}
#     - version: {{ cassandra.version }}

cassandra-server:
  archive.extracted:
    - name: /opt/
#   - source: http://apache.arvixe.com/cassandra/{{ cassandra.version }}/apache-cassandra-{{ cassandra.version }}-bin.tar.gz
#   - source: https://archive.apache.org/dist/cassandra/{{ cassandra.version }}/apache-cassandra-{{ cassandra.version }}-bin.tar.gz
    - source: {{ cassandra.path_to_package }}/{{ cassandra.package_name }}/{{ cassandra.version }}/{{ cassandra.package_name }}-{{ cassandra.version }}-bin.tar.gz
    {% if cassandra.version == "2.2.3" %}
    - source_hash: md5=36cbb2d03ad75698dff5e51159518d96
    {% elif cassandra.version == "2.2.4" %}
    - source_hash: md5=cb77a8e3792a7e8551af6602ac5f11df
    {% elif cassandra.version == "3.0.0" %}
    - source_hash: md5=2481e296834d0455c0a0c1a9f8e53e01
    {% endif %}
    - archive_format: tar
    - tar_options: xz
    - if_missing: /opt/apache-cassandra-{{ cassandra.version }}/

# Home directory
{% if 1 == salt['cmd.retcode']('test -f cassandra.home_dir') %}
{{ cassandra.home_dir }}:
  file.symlink:
    - target: /opt/apache-cassandra-{{ cassandra.version }}
{% endif %}

# Configuration files directory
{% if 1 == salt['cmd.retcode']('test -f cassandra.conf_dir') %}
{{ cassandra.conf_dir }}:
  file.symlink:
    - target: /opt/apache-cassandra-{{ cassandra.version }}/conf
{% endif %}

# Data files directory
{{ cassandra.data_dir }}:
  file.directory:
    - user: cassandra
    - group: cassandra
    - mode: 766
    - makedirs: True
    - recurse:
      - user
      - group
      - mode

cassandra_configuration:
  file.managed:
    - name: {{ cassandra.conf_dir }}/cassandra.yaml
    - user: root
    - group: root
    - mode: 644
    - source: salt://cassandra/files/cassandra_{{ cassandra.series }}.yaml
    - template: jinja
    - require:
      - archive: cassandra-server
#    - watch:
#      - file: {{ cassandra.home_dir }}/bin/cassandra

cassandra_rackdc_propertiies:
  file.managed:
    - name: {{ cassandra.conf_dir }}/cassandra-rackdc.properties
    - user: root
    - group: root
    - mode: 644
    - source: salt://cassandra/files/cassandra-rackdc.properties
    - template: jinja
    - watch:
      - file: cassandra_configuration

CASSANDRA_HOME:
# File.append searches the file for your text before it appends so it won't append multiple times
  file.append:
    - name: /home/cassandra/.bash_profile
    - text: export CASSANDRA_HOME={{ cassandra.home_dir }}
    - watch:
      - file: cassandra_configuration

CASSANDRA_CONF:
  file.append:
    - name: /home/cassandra/.bash_profile
    - text: export CASSANDRA_CONF={{ cassandra.conf_dir }}
    - watch:
      - file: cassandra_configuration

CASSANDRA_DATA:
  file.append:
    - name: /home/cassandra/.bash_profile
    - text: export CASSANDRA_DATA={{ cassandra.data_dir }}
    - watch:
      - file: cassandra_configuration

{% set current_path = salt['environ.get']('PATH', '/bin:/usr/bin') %}

ENV_PATH:
  file.append:
    - name: /home/cassandra/.bash_profile
    - text: export PATH={{ [current_path, cassandra.home_dir ~ '/bin']|join(':') }}
    - watch:
      - file: cassandra_configuration

{% for d in cassandra.config.data_file_directories %}
data_file_directories_{{ d }}:
  file.directory:
    - name: {{ d }}
    - user: cassandra
    - group: cassandra
    - mode: 755
    - makedirs: True
{% endfor %}

commitlog_directory:
  file.directory:
    - name: {{ cassandra.config.commitlog_directory }}
    - user: cassandra
    - group: cassandra
    - mode: 755
    - makedirs: True

saved_caches_directory:
  file.directory:
    - name: {{ cassandra.config.saved_caches_directory }}
    - user: cassandra
    - group: cassandra
    - mode: 755
    - makedirs: True

cassandra:
  cmd.run:
    - name: cassandra
    - user: cassandra
    - group: cassandra
    - env:
        - PATH: {{ [current_path, cassandra.home_dir ~ '/bin']|join(':') }}
    - require:
      - archive: cassandra-server
