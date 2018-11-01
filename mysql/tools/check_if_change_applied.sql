DROP PROCEDURE IF EXISTS mysql.check_if_change_applied;

CREATE PROCEDURE mysql.`check_if_change_applied`
(
     OUT out_error_code tinyINT,
     OUT out_alter_str text,
     in in_alter_type varchar(64),                        
     IN in_schema_name varchar(64),
     IN in_table_name varchar(64),
     IN in_column_name varchar(64),
     IN in_is_nullable varchar(3),                        
     IN in_column_type varchar(64),                       
     in in_is_auto_increment varchar(27),                 
     in in_column_default longtext,                       
     in in_new_column_name varchar(64)                    
    )
BEGIN

  DECLARE cnt int;
  DECLARE l_sql varchar(1000);
  DECLARE l_msg varchar(1000);

  SET out_error_code = -1;

  SET l_sql= CONCAT(' SELECT COUNT(*) INTO @cnt
                        FROM information_schema.columns
                       WHERE table_schema = LOWER(''', in_schema_name,''')
                         AND table_name = LOWER(''', in_table_name,''')
                         AND column_name = LOWER(''',  IF(in_new_column_name IS NULL, in_column_name, in_new_column_name),''')' 
                   );

  SET l_msg = CONCAT(in_column_name, ' column in ', in_schema_name,'.', in_table_name,' table with the following attributes: ');

  IF in_is_nullable IS NOT NULL THEN
    SET l_sql = CONCAT(l_sql, '\n AND is_nullable = upper(''', in_is_nullable, ''') ' );
    SET l_msg = CONCAT(l_msg, '\n ', IF(upper(in_is_nullable)='YES', 'NULL', 'NOT NULL') );
  END IF;

  IF in_column_type IS NOT NULL THEN
    SET l_sql = CONCAT(l_sql,  '\n AND column_type = LOWER(''', in_column_type, ''') ' );
    SET l_msg = CONCAT(l_msg, '\n ', UPPER(in_column_type) );
  END IF;

  IF in_is_auto_increment IS NOT NULL THEN
    SET l_sql = CONCAT(l_sql,  '\n AND extra = LOWER(''', in_is_auto_increment, ''') ' );
    SET l_msg = CONCAT(l_msg, '\n ', in_is_auto_increment );
  END IF;

  IF in_column_default IS NOT NULL AND LOWER(in_column_default)<>'null' THEN
    SET l_sql = CONCAT(l_sql,  '\n AND column_default = LOWER(', in_column_default, ') ' );
    SET l_msg = CONCAT(l_msg, '\n DEFAULT ', in_column_default );
  END IF;

  set @q=l_sql;
   
  PREPARE stmt FROM @q;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;

  IF @cnt=0 THEN
    IF ( LOWER(in_alter_type)='add') THEN
         SET out_alter_str = CONCAT( 'add ', LOWER(in_column_name), ' ', 
                                     UPPER(in_column_type), ' ' , 
                                     IF(UPPER(in_is_nullable) = 'YES', ' NULL ', 'NOT NULL '),
                                     IF(in_column_default IS NULL, '', 
                                       IF(LOWER(in_column_default) = 'null', ' DEFAULT NULL ',CONCAT(' DEFAULT ', in_column_default)
                                       ) 
                                     )
                                   );
    ELSEIF (LOWER(in_alter_type)='drop') THEN
      SET out_alter_str = null;
    ELSEIF (LOWER(in_alter_type)='modify') then
      SET out_alter_str = CONCAT( 'modify column ', LOWER(in_column_name), ' ', 
                 UPPER(in_column_type), ' ' , 
                 IF(upper(in_is_nullable)='YES',' NULL ', 'NOT NULL '),
                 IF(in_column_default IS NULL, '', IF(LOWER(in_column_default) = 'null', ' DEFAULT NULL ',CONCAT(' DEFAULT ',in_column_default)) ),  
                 IF(in_is_auto_increment IS NULL, '', ' AUTO_INCREMENT, AUTO_INCREMENT = 0')
                );
    ELSEIF (LOWER(in_alter_type)='change') THEN
       SET out_alter_str = CONCAT( 'change ', LOWER(in_column_name), ' ', 
                 LOWER(if(in_new_column_name is null, in_column_name, in_new_column_name)), ' ',
                 UPPER(in_column_type), ' ' , 
                 IF(upper(in_is_nullable)='YES', ' NULL ', 'NOT NULL '),
                 IF(in_column_default IS NULL, '', IF(LOWER(in_column_default)='null', ' DEFAULT NULL ',CONCAT(' DEFAULT ',in_column_default)) ) , 
                 IF(in_is_auto_increment IS NULL, '', ' AUTO_INCREMENT, AUTO_INCREMENT = 0' )
                );
    END IF;
  ELSE
    IF (LOWER(in_alter_type) = 'add') THEN
         SET out_alter_str = NULL;
    ELSEIF (LOWER(in_alter_type) = 'drop') THEN
         SET out_alter_str = CONCAT('DROP COLUMN ', LOWER(in_column_name) );
    ELSEIF (LOWER(in_alter_type) = 'modify') THEN
         SET out_alter_str = NULL;
    ELSEIF (LOWER(in_alter_type) = 'change') THEN
         SET out_alter_str = NULL;
    END IF;
  END IF;

  SET out_error_code = 0;

END;
