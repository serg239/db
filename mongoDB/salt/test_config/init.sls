# =============================================================================
# State:
#   //dev/test/proj/test_config/init.sls
# Description:
#   Check network interfaces
# Usage:
#   salt 'proj1-dev1' state.sls proj.test_config saltenv=test
# =============================================================================

# =====================================
# Test network interfaces
# Expected results:
#   . . .
#   auto eth0
#   iface eth0 inet static
#         address 10.10.62.172
#         netmask 255.255.255.0
#         network 10.10.62.0
#         broadcast 10.10.62.255
#         gateway 10.10.62.1
#   auto eth1
#   iface eth1 inet static
#         address 192.168.3.172
#         netmask 255.255.255.0
#         network 192.168.3.0
#         broadcast 192.168.3.255
#         gateway 192.168.3.1
#
network-interfaces-file:
  cmd.run:
    - name: cat /etc/network/interfaces

