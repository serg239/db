# =============================================================================
# driver/init.sls
# salt 'cas-node1' pkg.list_repo_pkgs gcc
#    base:
#        ----------
#        gcc:
#            - 4.4.7-16.el6
# salt 'cas-node1' pkg.list_repo_pkgs python-devel
#    base:
#        ----------
#        python-devel:
#            - 2.6.6-64.el6
#        python-devel.i686:
#            - 2.6.6-64.el6
# salt -E 'cas-node[1-4]' pip.list cassandra
# =============================================================================

#
# Download and install python-cassandra driver for salt.cassandra_cql module
#

#
# Download gcc and python development packages
#
dev-packages:
  pkg.installed:
    - pkgs:
      - gcc 
      - python-devel
      - wget

#
# Download get-pip.py file from PYPA
# 
download-get-pip:
  cmd.wait:
    - name: wget -P /opt https://bootstrap.pypa.io/get-pip.py
    - require:
      - pkg: dev-packages 

#
# Install PIP
#
install-pip:
  cmd.wait:
    - name: python /opt/get-pip.py
    - watch:
      - cmd: download-get-pip

#
# Download the driver
#
download-driver:
  cmd.run:
    - name: pip install cassandra-driver
    - watch:
      - cmd: install-pip
  
# =================================================
#
# =================================================
#
# Copy get-pip.py file to the /opt directory
#
get-pip-file:
   file.managed:
    - name: /opt/get-pip.py
    - user: root
    - group: root
    - mode: 755
    - source: salt://files/get-pip.py
    - require:
      - pkg: dev-packages
  