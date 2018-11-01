DROP PROCEDURE IF EXISTS mysql.check_alter_table;

CREATE PROCEDURE mysql.`check_alter_table`
(
 OUT out_error_code       TINYINT,
  IN in_schema_name       VARCHAR(64),
  IN in_table_name        VARCHAR(64),
  IN in_column_name       VARCHAR(64),
  IN in_is_nullable       VARCHAR(3),
  IN in_column_type       varchar(64),                       
  IN in_is_auto_increment varchar(27),                 
  IN in_column_default    longtext,                       
  IN in_alter_command     varchar(1000)
)
BEGIN

  DECLARE cnt INT;
  DECLARE l_sql VARCHAR(1000);
  DECLARE l_msg VARCHAR(1000);

  SET SQL_MODE='';

  SET out_error_code = -1;

  SET l_sql= CONCAT(
    'SELECT COUNT(*) INTO @cnt
       FROM information_schema.columns
      WHERE table_schema = LOWER(''',in_schema_name,''')
        AND table_name   = LOWER(''',in_table_name,''')
        AND column_name  = LOWER(''',in_column_name,''')
    ');

  SET l_msg = CONCAT(in_column_name, ' column IN ', in_schema_name,'.',in_table_name,' table with the following attributes: ');

  IF  in_is_nullable is not null then
    set l_sql = concat(l_sql,  '\n and is_nullable = upper(''', in_is_nullable, ''') ' );
    set l_msg = concat(l_msg, '\n ', if(upper(in_is_nullable)='YES','NULL', 'NOT NULL') );
  end if;

  if  in_column_type is not null then
    set l_sql = concat(l_sql,  '\n and column_type = lower(''', in_column_type, ''') ' );
    set l_msg = concat(l_msg, '\n ', upper(in_column_type) );
  end if;

  if  in_is_auto_increment is not null then
    set l_sql = concat(l_sql,  '\n and extra = lower(''', in_is_auto_increment, ''') ' );
    set l_msg = concat(l_msg, '\n ', in_is_auto_increment );
  end if;

  IF in_column_default IS NOT NULL THEN
    set l_sql = concat(l_sql,  '\n and column_default = lower(''', in_column_default, ''') ' );
    set l_msg = concat(l_msg, '\n default ', in_column_default );
  END IF;

  SET @q=l_sql;

  PREPARE stmt FROM @q;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;

  if @cnt=0 then

  set @q=in_alter_command;

  PREPARE stmt FROM @q;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;

  else
  set l_msg = concat('There IS ALREADY ',l_msg);
  select l_msg;
  end if;

  SET out_error_code = 0;

END;
