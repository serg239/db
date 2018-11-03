# =============================================================================
# Pillar:
#   //pillar/test/proj/mongodb/init.sls
# Description:
#   MongoDB configuration attributes
# =============================================================================
mongodb:

  repoIP:   '10.10.60.112'
  repoPath: 'builds/pod'
  fileName: 'mongodb-linux-x86_64-2.6.5'
  fileExt:  'tgz'
  hashType: 'md5'

  mongodbHomeDir:   '/opt/mongodb'
  mongodbDataDir:   '/opt/mongodb/data/db'
  mongodbLogDir:    '/opt/mongodb/data/log'
  mongodbConfigDir: '/opt/mongodb/conf'

  mongodbExecFile:   '/opt/mongodb/bin/mongo'
  mongodbDaemonFile: '/opt/mongodb/bin/mongod'

  # MiniPortal Name
  mpName: 'dev1'

  numBits: 647
  keyFileName: 'projMongodbKeyFile'
  
  # DB credentials
  adminUser:   'admin'
  adminPwd:    'test4321' 
  rootUser:    'root'
  rootPwd:     'test4321'
  localROUser: 'projro'
  localROPwd:  'test4321'

  # Databases:
  adminDBName: 'admin'
  projDBName:  'proj'
  mainDBName:  'proj-dbv01' 

  # Replica set name
  rsName: 'projMongoReplSet1'

  # multiple Replicas can be configured
  replicas:
    rs1:
      port: '27017'
    rs2:
      port: '27027'
    rs3:
      port: '27037'

  primPortNum: '27017'

