# =============================================================================
# cassandra/remove_node/init.sls
# =============================================================================
#
# Drop the Cassandra Node
#
{% from 'cassandra/node/settings.sls' import cassandra with context %}

#
# Stop the process
#
stop-process:
  module.run:
    - name: sh_utils.drop_process
    - kwargs:
      proc_name: "cassandra"

#
# Remove the saved_caches_directory
#
remove-saved-caches-dir:
  module.run:
    - name: sh_utils.remove_tree
    - kwargs:
      dir_path: {{ cassandra.config.saved_caches_directory }}
    - watch:
      - module: stop-process

#
# Remove the commitlog_directory
#
remove-commitlog-dir:
  module.run:
    - name: sh_utils.remove_tree
    - kwargs:
      dir_path: {{ cassandra.config.commitlog_directory }}
    - watch:
      - module: stop-process

#
# Remove the data_file_directories
#
remove-data-file-dirs:
{% for d in cassandra.config.data_file_directories %}
  module.run:
    - name: sh_utils.remove_tree
    - kwargs:
      dir_path: {{ d }}
    - watch:
      - module: stop-process
{% endfor %}

#
# Remove path to the home directory from the PATH for cassandra user
#
remove-from-path:
  module.run:
    - name: sh_utils.remove_from_path
    - kwargs:
      file_full_name: "/home/cassandra/.bash_profile"
      statement: {{ ':' ~ cassandra.home_dir ~ '/bin' }}
    - watch:
      - module: stop-process

#
# Remove the CASSANDRA_DATA environment variable
#
remove-data-env:
  module.run:
    - name: sh_utils.remove_env_variable
    - kwargs:
      file_full_name: "/home/cassandra/.bash_profile"
      var_name:  "CASSANDRA_DATA"
    - watch:
      - module: remove-from-path

#
# Remove the CASSANDRA_CONF environment variable
#
remove-conf-env:
  module.run:
    - name: sh_utils.remove_env_variable
    - kwargs:
      file_full_name: "/home/cassandra/.bash_profile"
      var_name:  "CASSANDRA_CONF"
    - watch:
      - module: remove-data-env

#
# Remove the CASSANDRA_HOME environment variable
#
remove-home-env:
  module.run:
    - name: sh_utils.remove_env_variable
    - kwargs:
      file_full_name: "/home/cassandra/.bash_profile"
      var_name:  "CASSANDRA_HOME"
    - watch:
      - module: remove-conf-env

#
# Remove the cassandra-rackdc.properties file
#
remove-rackdc-file:
  module.run:
    - name: sh_utils.remove_file
    - kwargs:
      file_full_name: {{ cassandra.conf_dir }}/cassandra-rackdc.properties
    - watch:
      - module: stop-process

#
# Remove the cassandra.yaml file
#
remove-config-file:
  module.run:
    - name: sh_utils.remove_file
    - kwargs:
      file_full_name: {{ cassandra.conf_dir }}/cassandra.yaml
    - watch:
      - module: stop-process

#
# Remove the data directory
#
remove-data-dir:
  module.run:
    - name: sh_utils.remove_tree
    - kwargs:
      dir_path: {{ cassandra.data_dir }}
    - watch:
      - module: stop-process

#
# Remove the symbolic link to the config directory
# /etc/cassandra/conf -> /opt/apache-cassandra-2.2.3/conf
#
remove-config-symlink:
  module.run:
    - name: sh_utils.remove_symlink
    - kwargs:
{% if 1 == salt['cmd.retcode']('test -L cassandra.conf_dir') %}
      file_full_name: {{ cassandra.conf_dir }}
{% endif %}
    - watch:
      - module: stop-process

#
# Remove the symbolic link to the home directory
# /opt/cassandra -> /opt/apache-cassandra-2.2.3
remove-home-symlink:
  module.run:
    - name: sh_utils.remove_symlink
    - kwargs:
{% if 1 == salt['cmd.retcode']('test -L cassandra.home_dir') %}
      file_full_name: {{ cassandra.home_dir }}
{% endif %}
    - watch:
      - module: stop-process

#
# Remove the installation directory /opt/apache-cassandra-2.2.3
#
remove-install-dir:
  module.run:
    - name: sh_utils.remove_tree
    - kwargs:
      dir_path: /opt/apache-cassandra-{{ cassandra.version }}
    - watch:
      - module: remove-home-symlink

# Drop JDK ???
# {% if cassandra.install_java %}
# java-1.8.0-openjdk:
#   pkg.installed:
#     - require_in:
#     - pkg: cassandra_package
#     - archive: cassandra-server
# {% endif %}
