# =============================================================================
# ntp/init.sls
# =============================================================================
ntp:
  pkg:
    - installed
#  service.running:
#    - name: ntpd
#    - enable: True
#    - watch:
#      - pkg: ntp
#      - file: /etc/ntp.conf
#      - user: ntp
#      - group: ntp
  user.present:
    - system: true
    - gid_from_name: true
    - home: /home/ntp
    - shell: /bin/bash
    - require:
      - group: ntp
      - pkg: ntp
  group.present:
    - require:
      - pkg: ntp

/etc/ntp.conf:
  file.managed:
    - name: /etc/ntp.conf
    - user: ntp
    - group: ntp
    - mode: 755
    - source: salt://files/ntp.conf.jinja
    - template: jinja
    - require:
      - pkg: ntp

ntp_log_directory:
  file.directory:
    - name: /srv/ntp/logs
    - user: ntp
    - group: ntp
    - mode: 755
    - makedirs: True
    - require:
      - user: ntp
      - group: ntp
      - pkg: ntp

run-ntp:
  cmd.run:
    - name: /etc/rc.d/init.d/ntpd start
    - user: root
    - group: root
    - watch:
      - file: /etc/ntp.conf
    - require:
      - pkg: ntp
   
