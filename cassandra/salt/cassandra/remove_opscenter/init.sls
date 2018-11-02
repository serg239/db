# =============================================================================
# remove_opscenter/init.sls
# =============================================================================
#
# Remove the DataStax OpsCenter -
# web-based visual management and monitoring solution for Apache Cassandra
#
{% set version = pillar['opscenter']['version'] %}
{% set home_dir = pillar['opscenter']['home_dir'] %}
{% set conf_dir = pillar['opscenter']['conf_dir'] %}

#
# Stop the process
#
stop-process:
  module.run:
    - name: sh_utils.drop_process
    - kwargs:
      proc_name: "opscenter"

#
# Remove configuration file
#
remove-config-file:
  module.run:
    - name: sh_utils.remove_file
    - kwargs:
      file_full_name: {{ conf_dir }}/opscenterd.conf
    - watch:
      - module: stop-process

#
# Remove the symbolic link to the home directory
# /opt/opscenter -> /opt/opscenter-5.2.2
#
remove-symlink:
  module.run:
    - name: sh_utils.remove_symlink
    - kwargs:
{% if 1 == salt['cmd.retcode']('test -L home_dir') %}
      file_full_name: {{ home_dir }}
{% endif %}
    - watch:
      - module: stop-process

#
# Remove the installation directory /opt/opscenter-5.2.2
#
remove-install-dir:
  module.run:
    - name: sh_utils.remove_tree
    - kwargs:
      dir_path: {{ home_dir }}-{{ version }}
    - watch:
      - module: remove-symlink

#
# Remove the configuration directory /etc/opscenter
#
remove-config-dir:
  module.run:
    - name: sh_utils.remove_tree
    - kwargs:
      dir_path: {{ conf_dir }}
    - watch:
      - module: remove-install-dir
