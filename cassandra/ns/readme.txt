Notification Service stack creation
===================================

Environment:
============
1. Add <stack_name> environment to salt-master /etc/salt/master configuration file:
Example - "dev" environment:
-----------------
file_roots:
. . . 
  dev:
    - /srv/salt/dev
. . .
pillar_roots:
. . .
  dev:
    - /srv/salt/pillar/dev
. . .    

2. Restart salt-master:
# service salt-master restart

# ===============================================

Files: 
======

1. Heat templates:
==================
The /srv/salt/dev/ns/files directory.

1.1. Jinja template of the NS heat environment file
* <stack_name>-<data_center>-ns-environment.jinja
Example:
* [dev-dc1]-ns-environment.jinja

1.2. Heat templates of all NS components:
* zookeeper-instance.yaml
* kafka-instance.yaml
* cassandra-instance.yaml
* ns-instance.yaml

1.3. Heat template to create new NS stack:
* <stack_name>-<data_center>-ns-full.yaml
Example:
* [dev-dc1]-ns-full.yaml

2. Salt state files:
====================
The /srv/salt/dev/ns directory.

2.1. set_heat_environment - to apply pillar values on <stack_name>-<data_center>-ns-environment.jinja file
                            and upload the generated <stack_name>-<data_center>-ns-environment.yaml 
                            file to controller (OpenStack).
/srv/salt/dev/ns/set_heat_environment/init.sls

2.2. upload_heat_templates - to upload all NS Heat template files from Salt server to controller (OpenStack):
/srv/salt/dev/ns/upload_heat_templates/init.sls

# ===============================================

Pillars [DEV/NS directory]:
===========================
Directory: /srv/salt/pillar/dev/ns
Files:
* zookeeper/init.sls
* kafka/init.sls
* cassandra/init.sls
* ns/init.sls
* ops/init.sls

2. Edit the ops pillar and change the stack_name and data_center values:
/srv/salt/pillar/dev/ns/ops/init.sls
ops:
  # OpenStack parameters
  stack_name: dev              # [dev|qa|stage|prod]
  data_center: dc1             # [dc1|dc2]

3. Add pillars for new stack in the top.sls file :
/srv/salt/pillar/top.sls
  '<stack_name>-<data_center>-*'
    - proxy
    - mines
Example:
  'dev-dc1-*'
    - proxy
    - mines

# ===============================================

Heat Templates and Salt States:
===============================
1. Rename JINJA template file in the /srv/salt/dev/ns/files directory to 
   <stack_name>-<data_center>-ns-environment.jinja
Example:
   dev-dc1-ns-environment.jinja

2. Run the salt state [Note: ]:
# salt 'ops' -l debug state.sls ns.set_heat_environment saltenv=dev
Result:
New <stack_name>-<data_center>-ns-environment.yaml file 
in the /etc/heat/templates directory on the controller (OpenStack).

3. Run the salt state [Note: the current salt environment is dev]:
# salt 'ops' -l debug state.sls ns.upload_heat_templates saltenv=dev
Result:
3.1. New or updated versions of the
* zookeeper-instance.yaml
* kafka-instance.yaml
* cassandra-instance.yaml and
* ns-instance.yaml
files in the /etc/heat/templates directory on the controller (OpenStack).
3.2. New <stack_name>-<data_center>-ns-full.yaml file 
in the /etc/heat/templates directory on the controller (OpenStack).

# ===============================================

To create new stack:
====================
# heat stack-create <stack_name>-<data_center> -f <stack_name>-<data_center>-ns-full.yaml -e <stack_name>-<data_center>-ns-environment.yaml -P 'broker_id'='%index%'
Example:
# heat stack-create dev-dc1 -f dev-dc1-ns-full.yaml -e dev-dc1-ns-environment.yaml -P 'broker_id=%index%'

Result [OpenStack]:
# heat stack-list
[root@openstack-controller templates]# heat stack-list
+--------------------------------------+--------------+-----------------+----------------------+
| id                                   | stack_name   | stack_status    | creation_time        |
+--------------------------------------+--------------+-----------------+----------------------+
| 534d2368-4ee8-4c44-980a-0e8b35e94008 | dev-dc1      | CREATE_COMPLETE | 2016-04-22T01:18:05Z |
+--------------------------------------+--------------+-----------------+----------------------+

# nova list
+--------------------+--------+------------+-------------+----------------------------------------+
| Name               | Status | Task State | Power State | Networks                               |
+--------------------+--------+------------+-------------+----------------------------------------+
| dev-dc1-ccr-0      | ACTIVE | -          | Running     | ns-internal=192.168.99.36, 10.9.60.188 |
| dev-dc1-ccr-1      | ACTIVE | -          | Running     | ns-internal=192.168.99.29, 10.9.60.181 |
| dev-dc1-ccr-2      | ACTIVE | -          | Running     | ns-internal=192.168.99.32, 10.9.60.185 |
| dev-dc1-ccs-0      | ACTIVE | -          | Running     | ns-internal=192.168.99.30, 10.9.60.183 |
| dev-dc1-ccs-1      | ACTIVE | -          | Running     | ns-internal=192.168.99.33, 10.9.60.186 |
| dev-dc1-ccs-2      | ACTIVE | -          | Running     | ns-internal=192.168.99.37, 10.9.60.190 |
| dev-dc1-kc-0       | ACTIVE | -          | Running     | ns-internal=192.168.99.39, 10.9.60.203 |
| dev-dc1-kc-1       | ACTIVE | -          | Running     | ns-internal=192.168.99.31, 10.9.60.184 |
| dev-dc1-kc-2       | ACTIVE | -          | Running     | ns-internal=192.168.99.35, 10.9.60.189 |
| dev-dc1-ns-0       | ACTIVE | -          | Running     | ns-internal=192.168.99.3, 10.9.60.182  |
| dev-dc1-zkc-0      | ACTIVE | -          | Running     | ns-internal=192.168.99.34, 10.9.60.187 |
| dev-dc1-zkc-1      | ACTIVE | -          | Running     | ns-internal=192.168.99.38, 10.9.60.191 |
| dev-dc1-zkc-2      | ACTIVE | -          | Running     | ns-internal=192.168.99.4, 10.9.60.204  |
+--------------------+--------+------------+-------------+----------------------------------------+

Result [Salt-Master, after 5-7 min]:
# salt-key -L | grep <stack_name>-<data_center>-

Example:
# salt-key -L | grep dev-dc1-
dev-dc1-ccr-0
dev-dc1-ccr-1
dev-dc1-ccr-2
dev-dc1-ccs-0
dev-dc1-ccs-1
dev-dc1-ccs-2
dev-dc1-kc-0
dev-dc1-kc-1
dev-dc1-kc-2
dev-dc1-ns-0
dev-dc1-zkc-0
dev-dc1-zkc-1
dev-dc1-zkc-2

# ===============================================
