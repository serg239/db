# =============================================================================
# Pillar:
#   //pillar/test/proj/tomcat/init.sls
# Description:
#   Tomcat configuration attributes
# =============================================================================
tomcat:

  repoIP:   '10.10.60.112'
  repoPath: 'builds/pod'
  fileName: 'apache-tomcat-7.0.56'
  fileExt:  'tar.gz'
  hashType: 'md5'

  tomcatHomeDir:   '/opt/tomcat7'
  tomcatConfigDir: '/opt/tomcat7/conf'
  tomcatWebDir:    '/opt/tomcat7/webapps'

