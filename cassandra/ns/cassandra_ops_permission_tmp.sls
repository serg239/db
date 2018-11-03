{% from 'common_settings.sls' import cc_user with context %}
{% set cassandra_private_ip = salt['grains.get']('private_ip','') %}


create_topic:
  cmd.run:
     - name: echo "GRANT CREATE ON ALL KEYSPACES TO {{ cc_user }}; GRANT ALTER ON ALL KEYSPACES TO {{ cc_user }}; exit" | cqlsh -u cassandra -p cassandra {{ cassandra_private_ip }}

