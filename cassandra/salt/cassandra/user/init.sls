# =============================================================================
# user/init.sls
# =============================================================================
cassandra-user:
  user.present:
    - name: {{ pillar['cassandra_user']['name'] }}
    - shell: /bin/bash
    - home: /home/{{ pillar['cassandra_user']['name'] }}
    - uid: {{ pillar['cassandra_user']['uid'] }}
    - gid: {{ pillar['cassandra_group']['gid'] }}
    - password: {{ pillar['cassandra_user']['password'] }}
