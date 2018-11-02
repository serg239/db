# =============================================================================
# remove_ntp/init.sls
# =============================================================================
#
# Stop NTP service and remove NTP files
#

#
# Stop NTP service
#
stop-ntp:
  cmd.run:
    - name: /etc/rc.d/init.d/ntpd stop
    - user: root
    - group: root
    - watch_in:
      - file: replace-ntp-file

#
# Replace NTP configuration file to original (CentOS v6.7)
#
replace-ntp-file:
  file.managed:
    - name: /etc/ntp.conf
    - user: root
    - group: root
    - mode: 755
    - source: salt://files/ntp.orig
    - template: jinja
    - watch_in:
      - module: remove-ntp-dir

#
# Remove NTP log directory
#
remove-ntp-dir:
  module.run:
    - name: sh_utils.remove_tree
    - kwargs:
      dir_path: /srv/ntp/logs
