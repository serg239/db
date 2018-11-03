# =============================================================================
# State:
#   //dev/test/proj/config/init.sls
# Description:
#   Check repository(ies), download and install missed packages, etc.
# Usage:
#   salt 'proj1-dev1' state.sls proj.config saltenv=test
# =============================================================================
{% set m                = salt['pillar.get']('mongodb', {}) %}
{% set mongodb_repo_ip  = m.get('repoIP', '10.10.60.252') %}
{% set wa               = salt['pillar.get']('web-appl', {}) %}
{% set web_appl_repo_ip = wa.get('repoIP', '10.10.60.252') %}
{% set t                = salt['pillar.get']('tomcat', {}) %}
{% set tomcat_repo_ip   = t.get('repoIP', '10.10.60.252') %}

# add-mongodb-repo-to-hosts:
#   host.present:
#     - ip: {{ mongodb_repo_ip }}
# add-web-appl-repo-to-hosts:
#   host.present:
#     - ip: {{ web_appl_repo_ip }}
# add-tomcat-repo-to_hosts:
#   host.present:
#    - ip: {{ tomcat_repo_ip }}

# =====================================
# Configure eth1 network interface
#
update-interfaces-file:
  file.managed:
    - name: /etc/network/interfaces
    - source: salt://proj/files/interfaces.jinja
    - template: jinja
    - mode: 644

restart-interface-eth1:
  cmd.run:
    - name: ifdown eth1 && ifup eth1
    - require:
      - file: update-interfaces-file

# =====================================
# Sync grains after restart interface(s)
#
sync-grains:
  module.run:
    - name: saltutil.sync_grains
    - refresh: True
    - require:
      - restart-interface-eth1

# =====================================
# Clean salt caches and update mines
#
# clean-mine-cache:
#  cmd.run:
#    - name: |
#        salt-run cache.clear_mine tgt='*' && \
#        salt '*' mine.update

