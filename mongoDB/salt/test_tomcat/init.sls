# =============================================================================
# State:
#   //dev/test/proj/test_tomcat/init.sls
# Description:
#   Test installed Tomcat package and created directories
# Usage:
#   salt 'proj1-dev1' state.sls proj.test_tomcat saltenv=test
# =============================================================================
{% set t = salt['pillar.get']('tomcat', {}) %}
{% set tomcat_conf_dir = t.get('tomcatConfDir', '/opt/tomcat7/conf') %}
{% set tomcat_web_dir  = t.get('tomcatWebDir', '/opt/tomcat7/webapps') %}

{% set wa = salt['pillar.get']('web-appl', {}) %}
{% set appl_config_dir = wa.get('applConfigDir', '/etc/proj/v2.0/conf') %}
{% set appl_artifact   = wa.get('artifact', 'proj-2.0') %}
{% set appl_file_name  = wa.get('fileName', '##1234567.war') %}

# =====================================
# Test installed Tomcat package
# Expected result:
#   libtomcat7-java/trusty-updates,trusty-security,now 7.0.52-1ubuntu0.8 all [installed,automatic]
#   tomcat7/trusty-updates,trusty-security,now 7.0.52-1ubuntu0.8 all [installed]
#   tomcat7-common/trusty-updates,trusty-security,now 7.0.52-1ubuntu0.8 all [installed,automatic]
#
# tomcat-packages:
#   cmd.run:
#    - name: apt list --installed | grep tomcat7

# =====================================
# Test the content of the webapps directory
# Expected result:
#   drwxr-xr-x  5 root root     4096 Jan 31 19:24 proj-2.0##1234567
#   -rw-r--r--  1 root root 22054429 Jan 31 19:24 proj-2.0##1234567.war
#   drwxr-xr-x 14 root root     4096 Sep 26  2014 docs
#   drwxr-xr-x  7 root root     4096 Sep 26  2014 examples
#   drwxr-xr-x  5 root root     4096 Sep 26  2014 host-manager
#   drwxr-xr-x  5 root root     4096 Sep 26  2014 manager
tomcat-web-dir:
  cmd.run:
    - name: ls -la {{ tomcat_web_dir }}

# =====================================
# Test the content of the web application directory
# Expected result:
#   drwxr-xr-x 3 root root 4096 Jan 31 19:24 META-INF
#   drwxr-xr-x 4 root root 4096 Jan 31 19:24 WEB-INF
#   drwxr-xr-x 7 root root 4096 Jan 31 19:24 documentation
#
tomcat-appl-dir:
  cmd.run:
    - name: ls -la {{ tomcat_web_dir }}/{{ appl_artifact }}{{ appl_file_name[:0-4] }}

# ===================================
# Test the content of the proj.properties file
# Expected result:
#   mongoReplicaSetHost=10.10.62.172:27017,10.10.62.172:27027,10.10.62.172:27037
#   mongoReplicaSetName=projMongoReplSet1
#   mongoDBName=proj-dbv01
#   mongoProjRWUserName=root
#   mongoProjRWPassword=lint1234
#   mongoLocalDBROUser=projro
#   mongoLocalDBROPassword=lint1234
#   apiBasePath=http://10.10.62.172:8080/proj-2.0/rest
#   projArtifact=proj-2.0
#   . . .
#
proj-properties-file:
  cmd.run:
    - name: cat {{ appl_config_dir }}/proj.properties

# ===================================
# Test the content of the proj_editable.properties file
# Expected result:
#   enableIPBasedAuthentication=true
#   writeAllowedIPList=10.10.62.170
#   enableProjStats=true
#
proj-editable-properties-file:
  cmd.run:
    - name: cat {{ appl_config_dir }}/proj_editable.properties
        
# ===================================
# Test connectors in server.xml file
# Expected result:
#   <Connector port="8071" protocol="org.apache.coyote.http11.Http11NioProtocol"
#   <Connector port="8080" protocol="HTTP/1.1"
#   <Connector executor="tomcatThreadPool"
#   <Connector port="8443" protocol="org.apache.coyote.http11.Http11Protocol"
#   <Connector port="8009" protocol="AJP/1.3" redirectPort="8443" /> 
#   
test-connectors-in-server-xml:
  cmd.run:
    - name: cat {{ tomcat_conf_dir }}/server.xml | grep "<Connector"

# =====================================
# Test status of the Tomcat service
# Expected result:
#   * Tomcat servlet engine is running with pid 8672  
#
# tomcat-status:
#   cmd.run:
#     - name: service tomcat7 status
