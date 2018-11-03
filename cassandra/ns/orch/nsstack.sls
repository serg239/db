zookeeper_deploy:
  salt.state:
    - tgt: '*ookeeper*'
    - sls: zookeeper

kafka_deploy:
  salt.state:
    - tgt: '*afka*'
    - sls: kafka
    - require:
      - salt: zookeeper_deploy

notification_service_deploy:
  salt.state:
    - tgt: 'salt-ns.cloudsol'
    - sls: notification_service
    - require:
      - salt: kafka_deploy
