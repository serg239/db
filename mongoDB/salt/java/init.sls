# =============================================================================
# State:
#   //dev/test/proj/java/init.sls
# Description:
#   Install Java
# Usage:
#   salt 'proj1-dev1' state.sls proj.java saltenv=test
# =============================================================================
{% set j = salt['pillar.get']('java', {}) %}
{% set pkg_name = j.get('pkgName', 'openjdk-7-jre') %}
{% set home_dir = j.get('homeDir', '/usr/lib/jvm/java-7-openjdk-amd64') %}

install-java:
  pkg.installed:
    - name: {{ pkg_name }}

set-java-home:
  file.append:
    - name: /root/.bashrc
    - text: export JAVA_HOME={{ home_dir }}
    - require:
      - pkg: install-java

