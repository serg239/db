# =============================================================================
# State:
#   //dev/test/proj/tomcat/init.sls
# Description:
#   Download package from repo
#   Upload config files
# Usage:
#   salt 'proj1-dev1' state.sls proj.tomcat saltenv=test
# =============================================================================
{% set t = salt['pillar.get']('tomcat', {}) %}

{% set tomcat_repo_ip   = t.get('repoIP', '10.10.60.252') %}
{% set tomcat_repo_path = t.get('repoPath', 'builds/controlpod') %}
{% set tomcat_file_name = t.get('fileName', 'apache-tomcat-7.0.56') %}
{% set tomcat_file_ext  = t.get('fileExt', 'tar.gz') %}
{% set tomcat_hash_type = t.get('hashType', 'md5') %}
{% set tomcat_full_path = 'http://' ~ tomcat_repo_ip ~ '/' ~ tomcat_repo_path ~ '/' ~ tomcat_file_name ~ '.' ~ tomcat_file_ext %}
{% set tomcat_hash_path = 'http://' ~ tomcat_repo_ip ~ '/' ~ tomcat_repo_path ~ '/' ~ tomcat_file_name ~ '.' ~ tomcat_file_ext ~ '.' ~ tomcat_hash_type %}

{% set tomcat_home_dir = t.get('tomcatHomeDir', '/opt/tomcat7') %}
{% set tomcat_conf_dir = t.get('tomcatConfDir', '/opt/tomcat7/conf') %}
{% set tomcat_web_dir  = t.get('tomcatWebDir', '/opt/tomcat7/webapps') %}

{% set wa = salt['pillar.get']('web-appl', {}) %}
{% set appl_repo_ip    = wa.get('repoIP', '10.10.60.252') %}
{% set appl_repo_path  = wa.get('repoPath', 'builds/controlpod') %}
{% set appl_artifact   = wa.get('artifact', 'proj-2.0') %}
{% set appl_file_name  = wa.get('fileName', '##1234567.war') %}
{% set appl_hash_type  = wa.get('hashType', 'md5') %}
{% set appl_full_path  = 'http://' ~ appl_repo_ip ~ '/' ~ appl_repo_path ~ '/' ~ appl_artifact ~ appl_file_name.replace('#', '%23') %}
{% set appl_hash_path  = 'http://' ~ appl_repo_ip ~ '/' ~ appl_repo_path ~ '/' ~ appl_artifact ~ appl_file_name.replace('#', '%23') ~ '.' ~ appl_hash_type %}
{% set appl_config_dir = wa.get('applConfigDir', '/etc/proj/v2.0/conf') %}

# ===================================
# Install tomcat from tarball in the repo
#
install-tomcat:
  archive.extracted:
    - name: /opt/
    - source: {{ tomcat_full_path }}
    - source_hash: {{ tomcat_hash_path }}
    - user: root
    - group: root
    - if_missing: {{ tomcat_home_dir }}

# ===================================
# Change the folder name
#
change-tomcat-folder-name:
  cmd.run:
    - name: mv /opt/{{ tomcat_file_name }} {{ tomcat_home_dir }}
    - onchanges:
      - archive: install-tomcat

# ===================================
# Download application's WAR file from repo
#
download-application:
  file.managed:
    - name: /opt/{{ appl_artifact }}{{ appl_file_name }}
    - source: {{ appl_full_path }}
    - source_hash: {{ appl_hash_path }}
    - user: root
    - group: root
    - mode: 644

# ===================================
# Create the application config directory
#
proj-config-dir:
  file.directory:
    - name: {{ appl_config_dir }}
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

# ===================================
# Upload proj.properties file
#
proj-properties-file:
  file.managed:
    - name: {{ appl_config_dir }}/proj.properties
    - source: salt://files/proj.properties.jinja
    - template: jinja
    - mode: 644
    - require:
      - file: proj-config-dir

# ===================================
# Upload proj_editable.properties file
#
proj-editable-properties-file:
  file.managed:
    - name: {{ appl_config_dir }}/proj_editable.properties
    - source: salt://files/proj_editable.properties.jinja
    - template: jinja
    - mode: 644
    - require:
      - file: proj-config-dir

# ===================================
# Clean the web application directory
#
clean-web-app:
  cmd.run:
    - name: rm -rf {{ tomcat_web_dir }}/ROOT*
    - require:
      - archive: install-tomcat

# ===================================
# Copy the web application
#
copy-web-app:
  cmd.run:
    - name: cp /opt/{{ appl_artifact }}* {{ tomcat_web_dir }}
    - require:
      - cmd: clean-web-app

# ===================================
# Update server.xml file with new connector on port 8071
#
update-server-file:
  file.managed:
    - name: {{ tomcat_conf_dir }}/server.xml
    - source: salt://files/server.xml.jinja
    - template: jinja
    - mode: 600
    - require:
      - cmd: change-tomcat-folder-name

# ===================================
# Start tomcat
#
start-tomcat:
  cmd.run:
    - name: {{ tomcat_home_dir }}/bin/startup.sh
#   - name: /etc/init.d/tomcat7 start
    - order: last

