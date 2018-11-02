# =============================================================================
# remove_user/init.sls
# =============================================================================
#
# Drop the Cassandra User
#
remove-user:
  user.absent:
    - name: {{ pillar['cassandra_user']['name'] }}
    - purge: True        # delete all of the user's files as well as the user 
    - force: True        # remove even if user is logged in
