Example of host with mongoDB as backend for web application
-----------------------------------------------------------

* Salt states and JINJA templates for:
  - host configuration:
    - network interfaces and sync salt grains 
  - mongodb:
    - download and install package from repo
    - create MongoDB with 3 replicas
    - create users
  - java:
    - install openjdk-7-jre package
    - configure JAVA_HOME
  - tomcat:
    - download tarball from local repo
    - download config files
    - download and install web application
    - configure application
    - start service
* Salt pillars:
    - java
    - mongodb
    - network
    - tomcat
    - web-appl
* top.sls for states and pillars
* test states for the installed components
