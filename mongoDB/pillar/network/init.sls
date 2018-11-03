# =============================================================================
# Pillar:
#   //pillar/proj/test/network/init.sls
# Description:
#   Configuration parameters of the network interfaces
# =============================================================================
network:

  domainName: 'domain'
  mgmtNetwork: '10.10.62.0/24'
  dnsServers:
    - '10.10.62.121'
    - '10.19.60.125'

  project:
    project1:
      mgmtIP: 10.10.62.112
      port: 8080
      webSocketPort: 8071
      dataIP: 192.168.1.112
#   project2:
#     mgmtIP: 10.9.62.113
#     port: 8080
#     webSocketPort: 8071
#     dataIP: 192.168.1.113
