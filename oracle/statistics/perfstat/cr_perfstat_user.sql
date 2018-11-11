CREATE USER perfstat 
  IDENTIFIED BY perf0rm
  DEFAULT TABLESPACE user_data
  TEMPORARY TABLESPACE temp
/
ALTER USER perfstat QUOTA 10M ON user_data
/
ALTER USER perfstat QUOTA 10M ON temp
/
GRANT CONNECT, RESOURCE TO perfstat
/
