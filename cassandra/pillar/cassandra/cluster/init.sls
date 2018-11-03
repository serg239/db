# =============================================================================
# /srv/salt/pillar/cassandra/cluster/init.sls
# =============================================================================
cluster:
  cluster_name: cc
  datacenter_name: dc1

  image_source_ip: http://buildarchive.org.com
  image_name: img-service-cassandra
  build_type: lvcloud.debug    # [lvcloud.debug|lvcloud.production]
  build_number: 185654

  tmp_zeromq_pkg_ip: http://192.168.99.116
  tmp_zeromq_pkg_name: python-zmq-14.3.1-1.el6.x86_64.rpm

  salt_master_ip: 10.10.60.48

  confd_admin_pwd: user_54321
  confd_enable_pwd: user_54321

  ops_user: {{ grains['ops_env']['user'] }}
  ops_pwd: {{ grains['ops_env']['pwd'] }}
  ops_auth_url: {{ grains['ops_env']['auth_url'] }}
  ops_tenant_name: {{ grains['ops_env']['tenant_name'] }}
  ops_region_name: {{ grains['ops_env']['region_name'] }}

  ops_project_name: cc
  ops_availability_zone: nova
  ops_flavor_name: m1.small
  ops_cassandra_instances:
    - ccdc1-01
    - ccdc1-02
    - ccdc1-03
    - ccdc1-04
  ops_key_pair_name: jdlkey
  ops_security_groups:
    - ABC
    - default
  ops_private_networks:
    - poc-network
  ops_private_subnets:
    - poc-subnet
  ops_public_networks:
    - public

  cassandra:
    deployment: dc1
    cluster_name: cc
    endpoint_snitch: GossipingPropertyFileSnitch