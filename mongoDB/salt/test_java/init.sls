# =============================================================================
# State:
#   //dev/test/proj/test_java/init.sls
# Description:
#   Test installed JAVA package and created directories
# Usage:
#   salt 'proj1-dev1' state.sls proj.test_java saltenv=test
# =============================================================================
{% set j  = salt['pillar.get']('java', {}) %}
{% set java_home_dir = j.get('homeDir', '/usr/lib/jvm/java-7-openjdk-amd64') %}

# =====================================
# Test installed JAVA packages
# Expected result:
#
#
java-packages:
  cmd.run:
    - name: apt list --installed | grep java

# =====================================
# Test JAVA_HOME record in the root .bashrc file
# Expected result:
#   
#
java-home-in-tomcat-config:
  cmd.run:
    - name: cat /root/.bashrc | grep "export JAVA_HOME"

# =====================================
# Test the files in JAVA home directory
# Expected result:
#    drwxr-xr-x 2 root root 4096 Jan 20 11:27 bin
#    lrwxrwxrwx 1 root root   41 Nov 16 00:09 docs -> ../../../share/doc/openjdk-7-jre-headless
#    drwxr-xr-x 5 root root 4096 Jan 20 11:27 jre
#    drwxr-xr-x 4 root root 4096 Jan 20 11:27 man
#
java-home-dir-files:
  cmd.run:
    - name: ls -la {{ java_home_dir }}
