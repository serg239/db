# =============================================================================
# /srv/salt/pillar/cassandra/ports/init.sls
# ============================================================================= 
# Cassandra Ports:
# 7000  - Inter-node cluster communication.
# 7001  - SSL inter-node cluster communication.
# 7199  - JMX monitoring port.
# 9042  - Client port.
# 9160  - Client thrift port.
# 61619 - OpsCenter monitoring port. The opscenterd daemon listens on this port for TCP traffic coming from the agent.
# 61621 - OpsCenter agent port. The agents listen on this port for SSL traffic initiated by OpsCenter.
# 8888  - The opscenterd daemon listens on this port for HTTP requests coming directly from the browser.

ports:
  cas-node1:
    internal_ports:
      - 7000
      - 7001
      - 7199
      - 9042
      - 9160
#     - 61619
#     - 61621
    public_ports:
      - 8888

  cas-node2:
    internal_ports:
      - 7000
      - 7001
      - 7199
      - 9042
      - 9160
#     - 61619
#     - 61621
    public_ports:
      - 8888

  cas-node3:
    internal_ports:
      - 7000
      - 7001
      - 7199
      - 9042
      - 9160
#     - 61619
#     - 61621
    public_ports:
      - 8888

  cas-node4:
    internal_ports:
      - 7000
      - 7001
      - 7199
      - 9042
      - 9160
#     - 61619
#     - 61621
    public_ports:
      - 8888
