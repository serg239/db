# ============================================================================= 
# cassandra/tune/init.sls
# ============================================================================= 
/etc/cassandra/cassandra-env.sh:
  file:
    - managed
    - source: salt://files/cassandra-env.sh
    - user: cassandra
    - group: cassandra
    - mode: 644
    - template: jinja
    - require:
      - archive: cassandra-server
