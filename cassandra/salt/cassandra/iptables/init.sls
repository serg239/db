# =============================================================================
# /srv/salt/cassandra/iptables/init.sls
# =============================================================================
{% if (grains['osfullname'] == 'CentOS') and (grains['osmajorrelease'] == '6') %}
{%   set path='/etc/sysconfig/iptables' %}
{% elif grains['os_family'] == 'Debian' %}
{%   set path='/etc/network/if-pre-up.d/iptables' %}
{% endif %}

iptables:
  pkg:
    - installed
  file.managed:
    - name: {{ path }}
    - user: root
    - group: root
    - mode: 755
    - source: salt://files/iptables.jinja
    - template: jinja
  cmd.wait:
    - name: iptables-restore < {{ path }}
    - watch:
      - file: iptables
    - require:
      - pkg: iptables

      