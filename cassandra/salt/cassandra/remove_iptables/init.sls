# =============================================================================
# remove_iptables/init.sls
# =============================================================================
#
# Replace firewall config file to original
# and restart service
#

{% if (grains['osfullname'] == 'CentOS') and (grains['osmajorrelease'] == '6') %}
{% set path='/etc/sysconfig/iptables' %}
{% elif grains['os_family'] == 'Debian' %}
{% set path='/etc/network/if-pre-up.d/iptables' %}
{% endif %}

#
# Replace firewall config file
#
drop-file:
  file.managed:
    - name: {{ path }}
    - user: root
    - group: root
    - mode: 755
    - source: salt://files/iptables.orig
    - template: jinja
    - watch_in:
      - cmd: restart-firewall

#
# Restart service
#
restart-firewall:
  cmd.run:
    - name: service iptables restart
