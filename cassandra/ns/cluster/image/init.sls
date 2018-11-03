# =============================================================================
# Script [master]:
#   /srv/salt/ns/cassandra/cluster/image/init.sls
# Description:
#   Download and install cassandra image
# Usage:
#   salt 'ops' -l debug state.sls cluster.image saltenv=ns
# To delete image:
# Config pillars: /srv/salt/pillar/ns/top.sls:
#   base:
#     'ops':
#       - ns.cassandra.cluster
# Config states: /srv/salt/ns/top.sls:
#   ns:
#     'ops':
#       - cassandra.cluster
# =============================================================================
# TOP sls: /srv/salt/ns/cassandra/top.sls
#   cassandra:
#    'cas-node*':
#      - seed
#      - node
#      - database
#      - data
#    'nsccdc1*':
#      - cluster.image
# =============================================================================

{% set p  = salt['pillar.get']('cluster', {}) %}

# =====================================
# Assign the build image values
# =====================================
{% set image_source_ip = p.get('image_source_ip', 'http://buildarchive.bluecoat.com') %}
{% set image_name = p.get('image_name', 'coe-service-cassandra') %}
{% set build_number = p.get('build_number', '185573') %}
{% set build_type = p.get('build_type', 'debug') %}
{% if build_type == 'lvcloud.debug' %}
  {% set full_zip_file_name = image_name ~ '-' ~ build_number ~ '-lvcloud.debug.vhd.gz' %}
  {% set full_unzip_file_name = image_name ~ '-' ~ build_number ~ '-lvcloud.debug.vhd' %}
  {% set full_image_name = image_name ~ '-' ~ build_number ~ '-lvcloud.debug' %}
{% else %}
  {% set full_zip_file_name = image_name ~ '-' ~ build_number ~ '-lvcloud.vhd.gz' %}
  {% set full_unzip_file_name = image_name ~ '-' ~ build_number ~ '-lvcloud.vhd' %}
  {% set full_image_name = image_name ~ '-' ~ build_number ~ '-lvcloud' %}
{% endif %}
{% set ops_source_file_name = p.get('ops_source_file_name', '~/keystonerc_demo') %}

remove-old-src-file:
  file.absent:
    - name: /tmp/{{ full_zip_file_name }}

download-new-src-file:
  cmd.run:
    - name: wget -P /tmp {{ image_source_ip }}/{{ image_name }}.{{ build_number }}/iso/{{ full_zip_file_name }}
    - user: root
    - group: root
    - requires:
      - file: remove-old-src-file

unpack-image-file:
  cmd.run:
    - name: gunzip /tmp/{{ full_zip_file_name }}
    - require:
      - cmd: download-new-src-file

add-image-to-glance:
  cmd.run:
    - name: source {{ ops_source_file_name }} && glance image-create --name {{ full_image_name }} --disk-format vhd --container-format bare --is-public True --file /tmp/{{ full_unzip_file_name }}
    - require:
      - cmd: unpack-image-file

assign-metadata-to-image:
  cmd.run:
    - name: source {{ ops_source_file_name }} && nova image-meta {{ full_image_name }} set vm_mode=hvm
    - require:
      - cmd: add-image-to-glance

remove-image-file:
  file.absent:
    - name: /tmp/{{ full_unzip_file_name }}
    - order: last
    - require:
      - cmd: add-image-to-glance
