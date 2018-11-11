SPOOL cr_perfstat_schema.lst

CONNECT perfstat/perf0rm@cvtest

DROP TABLE perfstat.stats$ddl_log
/
CREATE TABLE perfstat.stats$ddl_log
(
  user_name  VARCHAR2(16),
  DDL_date   DATE,
  DDL_event  VARCHAR2(32),
  obj_type   VARCHAR2(20),
  obj_owner  VARCHAR2(16),
  obj_name   VARCHAR2(32)
 )
TABLESPACE user_data
/

DROP TABLE perfstat.stats$user_conn
/
CREATE TABLE perfstat.stats$user_conn
(
  user_name     VARCHAR2(16),
  event_action  VARCHAR2(32),
  event_date    DATE,
  IP_address    VARCHAR2(32),
  instance_num  NUMBER
)
TABLESPACE user_data
/

DROP TABLE perfstat.stats$servererror_log
/
CREATE TABLE perfstat.stats$servererror_log
(
  error     VARCHAR2(30),
  datestamp DATE,
  username  VARCHAR2(16),
  osuser    VARCHAR2(16),
  machine   VARCHAR2(48),
  process   VARCHAR2(8),
  program   VARCHAR2(48)
)
TABLESPACE user_data
/

CONNECT sys/cr0ss@cvtest

CREATE OR REPLACE TRIGGER DDL_trig
AFTER DDL ON DATABASE
BEGIN
  INSERT INTO perfstat.stats$ddl_log(user_name, DDL_date, DDL_event, obj_type, obj_owner, obj_name)
  VALUES (ora_login_user, SYSDATE, ora_sysevent, ora_dict_obj_type, ora_dict_obj_owner, ora_dict_obj_name);
END;
/

REM ===================================================================
REM                          CLIENT EVENTS
REM ===================================================================
REM Event           When Fired?                     Attribute Functions
REM ===================================================================
REM AFTER LOGON     After a successful              ora_sysevent
REM                 logon of a user.                ora_login_user
REM                                                 ora_instance_num
REM                                                 ora_database_name
REM                                                 ora_client_ip_address

CREATE OR REPLACE TRIGGER logon_trig 
AFTER LOGON ON DATABASE
BEGIN
  INSERT INTO perfstat.stats$user_conn (user_name, event_action, event_date, IP_address, instance_num) 
  VALUES (ora_login_user, ora_sysevent, SYSDATE, ora_client_ip_address, ora_instance_num);
END;
/

REM ===================================================================
REM                          CLIENT EVENTS
REM ===================================================================
REM Event           When Fired?                     Attribute Functions
REM ===================================================================
REM BEFORE LOGOFF   At the start of a user logoff   ora_sysevent
REM                                                 ora_login_user
REM                                                 ora_instance_num
REM                                                 ora_database_name

CREATE OR REPLACE TRIGGER logoff_trig 
BEFORE LOGOFF ON DATABASE
BEGIN
  INSERT INTO perfstat.stats$user_conn (user_name, event_action, event_date, IP_address, instance_num) 
  VALUES (ora_login_user, ora_sysevent, SYSDATE, ora_client_ip_address, ora_instance_num);
END;
/

CREATE OR REPLACE TRIGGER log_errors_trig
AFTER SERVERERROR ON DATABASE
DECLARE
  v_err_msg  VARCHAR2(30);
  v_user     VARCHAR2(16);
  v_osuser   VARCHAR2(16);
  v_machine  VARCHAR2(48);
  v_process  VARCHAR2(8);
  v_program  VARCHAR2(48);
BEGIN
  IF SQLCODE <> 0 THEN
    SELECT username,
           osuser,
           machine,
           process,
           program
      INTO v_user,
           v_osuser,
           v_machine,
           v_process,
           v_program
      FROM v$session
     WHERE audsid = USERENV('SESSIONID');
    v_err_msg := SUBSTR(SQLERRM, 1, 30);
    INSERT INTO perfstat.stats$servererror_log
    VALUES(v_err_msg, SYSDATE, v_user, v_osuser, v_machine, v_process, v_program);
  END IF;  
END;
/

CONNECT perfstat/perf0rm@cvtest

SPOOL OFF

