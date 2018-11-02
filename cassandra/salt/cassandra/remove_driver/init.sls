# =============================================================================
# cassandra/remove_driver/init.sls
# Test:
#   salt -E 'cas-node[1-4]' pip.list cassandra
# =============================================================================
#
# Remove python-cassandra driver
#

#
# Remove the /opt/get-pip.py file
#
remove-pip-file:
  module.run:
    - name: sh_utils.remove_file
    - kwargs:
      file_full_name: /opt/get-pip.py

#
# Uninstall package with pip
#
uninstall-driver:
  module.run:
    - name: pip.uninstall
    - pkgs: cassandra-driver
    - user: root
    - cwd: /opt      # Current working directory to run pip from
    - watch:
      - module: remove-pip-file
