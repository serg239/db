/*
-- HOST
Notes:
  !!! Dynamic SQL is not allowed in stored function or trigger !!!
*/

DELIMITER $$

DROP FUNCTION IF EXISTS test.exec_command$$

CREATE FUNCTION test.exec_command
(
  command_id_in INTEGER
)
RETURNS INTEGER
DETERMINISTIC
BEGIN

  DECLARE is_running TINYINT DEFAULT 0;

  SET @sql_stmt = '';
  SET @LF = CHAR(10);

  TRUNCATE TABLE test.exec_result;

  SELECT CONCAT('INSERT INTO test.exec_result', @LF,
                select_clause, @LF,
                from_clause, @LF,
                IFNULL(where_clause, ''),
                IFNULL(order_clause, '')
               )
    INTO @sql_stmt
    FROM test.exec_commands
   WHERE exec_command_id = command_id_in;
   
  IF LENGTH(@sql_stmt) > 1 THEN 
    PREPARE query FROM @sql_stmt;
    EXECUTE query;
    DEALLOCATE PREPARE query;
  END IF;
 
  RETURN 1;

END$$

DELIMITER ;

/*
--
CREATE TABLE IF NOT EXISTS test.exec_record
(
  record VARCHAR(128)
)
ENGINE = InnoDB;
*/

--
DROP TABLE IF EXISTS test.exec_commands;
--
CREATE TABLE IF NOT EXISTS test.exec_commands
(
  exec_command_id  INTEGER      NOT NULL,
  select_clause    VARCHAR(512) NOT NULL,
  from_clause      VARCHAR(512) NOT NULL,
  where_clause     VARCHAR(512),
  order_clause     VARCHAR(128)
)
ENGINE = InnoDB;

--
CREATE TABLE IF NOT EXISTS test.exec_result
(
  exec_result_id   INTEGER      NOT NULL AUTO_INCREMENT,
  col_01           VARCHAR(128),
  col_02           VARCHAR(128),
  col_03           VARCHAR(128),
  col_04           VARCHAR(128),
  col_05           VARCHAR(128),
  col_06           VARCHAR(128),
  col_07           VARCHAR(128),
  col_08           VARCHAR(128),
  col_09           VARCHAR(128),
  col_10           VARCHAR(128),
  PRIMARY KEY exec_results$exec_result_id_pk (exec_result_id)
)
ENGINE = InnoDB;

CREATE VIEW exec_view
AS
SELECT col_01 AS id,
       col_02 AS user, 
       col_03 AS host, 
       col_04 AS db, 
       col_05 AS command, 
       col_06 AS time
  FROM test.exec_result
 WHERE test.exec_command(1) = 1;

/*
-- Client --
DROP TABLE IF EXISTS test.fed_exec_commands;
--
CREATE TABLE test.fed_exec_commands
(  
  exec_command_id  INTEGER      NOT NULL,
  select_clause    VARCHAR(512) NOT NULL,
  from_clause      VARCHAR(512) NOT NULL,
  where_clause     VARCHAR(512),
  order_clause     VARCHAR(128),
  PRIMARY KEY fed_exec_commands$exec_command_id_pk (exec_command_id)
)
ENGINE = FEDERATED
CONNECTION = 'mysql://data_owner:data_owner@dbtrunk-db2:3306/test/exec_commands';

INSERT INTO test.fed_exec_commands (exec_command_id, select_clause, from_clause, where_clause, order_clause) VALUES
(1,
 "SELECT id, user, host, db, command, time", 
 "FROM information_schema.processlist", 
 "WHERE user = 'db_user' AND host = 'dbtrunk-db3' AND command = 'Sleep'", 
 "ORDER BY id"
);

-- ERROR 1296 (HY000): Got error 10000 'Error on remote system: 1142: INSERT command denied to user 'db_user'@'dbtrunk-db3.intro.net'' from FEDERATED

-- Client
CREATE TABLE test.fed_exec_result
(  
  id       BIGINT(4)   NOT NULL DEFAULT "0",
  user     VARCHAR(16) NOT NULL DEFAULT "",
  host     VARCHAR(64) NOT NULL DEFAULT "",
  db       VARCHAR(64),
  command  VARCHAR(16) NOT NULL DEFAULT "",
  time     INTEGER(7)  NOT NULL DEFAULT "0"
)
ENGINE = FEDERATED
CONNECTION = 'mysql://db_user:db_user@dbtrunk-db2:3306/test/exec_view';
*/
