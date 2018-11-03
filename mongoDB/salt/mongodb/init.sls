# =============================================================================
# State:
#   //dev/test/proj/mongodb/init.sls
# Description:
#   Download package from repo
#   Create MongoDB DB with 3 replicas
#   Create users in the DB
# Usage:
#   salt 'proj1-dev1' state.sls proj.mongodb saltenv=test
# =============================================================================
{% set m = salt['pillar.get']('mongodb', {}) %}
{% set repo_ip = m.get('repoIP', '10.10.60.252') %}
{% set repo_path = m.get('repoPath', 'builds/controlpod') %}
{% set file_name = m.get('fileName', 'mongodb-linux-x86_64-2.6.5') %}
{% set file_ext  = m.get('fileExt', 'tgz') %}
{% set hash_type = m.get('hashType', 'md5') %}
{% set mongo_full_path = 'http://' ~ repo_ip ~ '/' ~ repo_path ~ '/' ~ file_name ~ '.' ~ file_ext %}
{% set mongo_hash_path = 'http://' ~ repo_ip ~ '/' ~ repo_path ~ '/' ~ file_name ~ '.' ~ file_ext ~ '.' ~ hash_type %}
{% set mp_name = m.get('mpName', 'dev1') %}

{% set mongodb_home_dir   = m.get('mongodbHomeDir', '/opt/mongodb') %}
{% set mongodb_data_dir   = m.get('mongodbDataDir', '/opt/mongodb/data/db') %}
{% set mongodb_log_dir    = m.get('mongodbLogDir', '/opt/mongodb/data/log') %}
{% set mongodb_config_dir = m.get('mongodbConfigDir', '/opt/mongodb/conf') %}

{% set num_bits = m.get('numBits', '742') %}
{% set key_file_name = m.get('keyFileName', 'projMongodbKeyFile') %}

{% set mongodb_exec_file   = m.get('mongodbExecFile', '/opt/mongodb/bin/mongo') %}
{% set mongodb_daemon_file = m.get('mongodbDaemonFile', '/opt/mongodb/bin/mongod') %} 
{% set prim_port_num       = m.get('primPortNum', '27017') %} 

# ===================================
# Install mongodb from tarball in the repo
#
install-mongodb:
  archive.extracted:
    - name: /opt/
    - source: {{ mongo_full_path }}
    - source_hash: {{ mongo_hash_path }}
    - user: root
    - group: root
#   - skip_verify: True
    - if_missing: {{ mongodb_home_dir }}

# ===================================
# Change the folder name
#
change-mongodb-folder-name:
  cmd.run:
    - name: mv /opt/{{ file_name }} {{ mongodb_home_dir }}
    - onchanges: 
      - archive: install-mongodb

# ===================================
# Create the working DB directories 
#
{% for r in m.replicas %}
db-dir-{{ m.replicas[r].port }}:
  file.directory:
    - name: {{ mongodb_data_dir }}/{{ mp_name }}rs{{ m.replicas[r].port }}
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
    - require:
      - cmd: change-mongodb-folder-name
{% endfor %}

# ===================================
# Create the working Log directories
#
{% for r in m.replicas %}
log-dir-{{ m.replicas[r].port }}:
  file.directory:
    - name: {{ mongodb_log_dir }}/{{ mp_name }}rs{{ m.replicas[r].port }}
    - user: root
    - group: root
    - mode: 755
    - makedirs: True
    - require:
      - cmd: change-mongodb-folder-name
{% endfor %}

# ===================================
# Create the Key file for authentication
#
key-file:
  cmd.run:
    - name: openssl rand -base64 {{ num_bits }} > {{ mongodb_home_dir }}/{{ key_file_name }}
    - require:
      - cmd: change-mongodb-folder-name

key-file-mode:
  file.managed:
    - name: {{ mongodb_home_dir }}/{{ key_file_name }}
    - mode: 700
    - require:
      - cmd: key-file

# ===================================
# Create MongoDB configuration directory
#
create-mongodb-config-dir: 
  file.directory:
    - name: {{ mongodb_config_dir }}
    - mode: 644
    - makedirs: True

# ===================================
# Upload configuration files for all DB replicas
#
{% for r in m.replicas %}
config-file-{{ m.replicas[r].port }}:
  file.managed:
    - name: {{ mongodb_config_dir }}/{{ mp_name }}rs{{ m.replicas[r].port }}.conf
    - source: salt://files/mongodb_rs_config.jinja
    - template: jinja
    - mode: 644
    - context:
      replica_port_num: {{ m.replicas[r].port }}
      mp_name:          {{ mp_name }}
      mongodb_data_dir: {{ mongodb_data_dir }}
      mongodb_log_dir:  {{ mongodb_log_dir }}
      mongodb_home_dir: {{ mongodb_home_dir }}
      key_file_name:    {{ key_file_name }}
    - require:
      - file: create-mongodb-config-dir
{% endfor %}

# ===================================
# Upload mongodb JS file to create replicas
#
upload-create-replicas-file:
  file.managed:
    - name: {{ mongodb_config_dir }}/mongodb_create_replicas.js
    - source: salt://files/mongodb_create_replicas.jinja
    - template: jinja
    - mode: 644
    - require:
      - file: create-mongodb-config-dir

# ===================================
# Upload mongodb JS file to create users
#
upload-create-users-file:
  file.managed:
    - name: {{ mongodb_config_dir }}/mongodb_create_users.js
    - source: salt://files/mongodb_create_users.jinja
    - template: jinja
    - mode: 644
    - require:
      - file: create-mongodb-config-dir

# ===================================
# Upload shell script to start daemons
#
upload-start-mongo-file:
  file.managed:
    - name: {{ mongodb_config_dir }}/startMongo.sh
    - source: salt://files/mongodb_start_mongo.jinja
    - template: jinja
    - mode: 644
    - require:
      - file: create-mongodb-config-dir

# ===================================
# Run mongod processes for all DB replicas
#
{% for r in m.replicas %}
run-mongod-{{ m.replicas[r].port }}:
  cmd.run:
    - name: nohup {{ mongodb_daemon_file }} --config {{ mongodb_config_dir }}/{{ mp_name }}rs{{ m.replicas[r].port }}.conf &
    - require:
      - file: config-file-{{ m.replicas[r].port }}
{% endfor %}

# ===================================
# Initialize the DB
#
db-init:
  cmd.run:
    - name: {{ mongodb_exec_file }} < {{ mongodb_config_dir }}/mongodb_create_replicas.js
    - require:
      - cmd: run-mongod-{{ prim_port_num }}
      - file: upload-create-replicas-file

# ===================================
# Wait 60 sec
#
wait-60sec:
  cmd.run:
    - name: sleep 60
    - require:
      - cmd: db-init

# ===================================
# Configure users
#
db-add-users:
  cmd.run:
    - name: {{ mongodb_exec_file }} -p {{ prim_port_num }} < {{ mongodb_config_dir }}/mongodb_create_users.js
    - wait:
      - cmd: wait-60sec 

