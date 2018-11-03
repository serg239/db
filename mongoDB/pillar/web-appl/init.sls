# =============================================================================
# Pillar:
#   //pillar/test/proj/web-appl/init.sls
# Description:
#   Project configuration attributes
# =============================================================================
web-appl:

  repoIP:   '10.10.60.112'
  repoPath: 'builds/pod'
  artifact: 'proj-2.0'
  fileName: '##1234567.war'
  hashType: 'md5'

  applVersion:   'v2.0'
  applConfigDir: '/etc/dev/proj/v2.0/conf'
  applConnPort:  '8071'

