DROP PROCEDURE IF EXISTS mysql.clean_ddl;

CREATE PROCEDURE mysql.`clean_ddl`(OUT error_code INT, IN in_schema_exclusion_list TEXT)
BEGIN

DECLARE v_table_name         VARCHAR(64);
DECLARE v_table_schema       VARCHAR(64);
DECLARE v_column_name        VARCHAR(64);
DECLARE v_column_default     LONGTEXT ;
DECLARE v_is_nullable        VARCHAR(3);
DECLARE v_column_type        LONGTEXT;
DECLARE v_character_set_name VARCHAR(32);
DECLARE v_collation_name     VARCHAR(32);
DECLARE v_column_comment     VARCHAR(255);
DECLARE v_index_name         VARCHAR(64);
DECLARE no_more_rows         INT;


DECLARE v_schema_exclusion_list TEXT DEFAULT CONCAT(in_schema_exclusion_list,',information_schema,mysql');

DECLARE cur_info_coulumn CURSOR FOR
SELECT table_schema, 
       table_name, 
       column_name, 
       is_nullable,
       column_default,
       column_type,
       character_set_name,
       collation_name,
       column_comment
   FROM information_schema.columns 
  WHERE NOT FIND_IN_SET(table_schema,REPLACE(v_schema_exclusion_list,' ','')) 
    AND extra ='auto_increment'
  ORDER 
     BY table_schema, table_name;

DECLARE cur_info_fk CURSOR FOR
SELECT table_schema,
       constraint_name,  
       table_name  
  FROM information_schema.table_constraints 
 WHERE constraint_type = 'FOREIGN KEY'
   AND NOT FIND_IN_SET(table_schema,REPLACE(v_schema_exclusion_list,' ',''))
 ORDER 
    BY table_schema, table_name;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET no_more_rows = 1;

SET error_code = -2;
SET SQL_MODE = '';

    
    OPEN cur_info_coulumn;
    SET @command = '';

    COLUMNS:
    LOOP
        SET no_more_rows = 0;

        FETCH cur_info_coulumn
        INTO        v_table_schema,
                    v_table_name,
                    v_column_name,
                    v_is_nullable,
                    v_column_default,
                    v_column_type,
                    v_character_set_name,
                    v_collation_name,
                    v_column_comment; 

        IF no_more_rows = 1
        THEN
            LEAVE COLUMNS;
        END IF;

    
    SET @command = CONCAT( 'ALTER TABLE  ',v_table_schema , '.',v_table_name, ' modify column ', LOWER(v_column_name), ' ', 
                                UPPER(v_column_type), ' ' ,IF(UPPER(v_is_nullable)='YES',' NULL ', 'NOT NULL '),
                                IF(v_column_default IS NULL,'',IF(LOWER(v_column_default)='null', ' default null ',CONCAT(' default ','"',v_column_default,'"')) ),
                                IF(v_character_set_name IS NULL,'',CONCAT(' CHARACTER SET ',v_character_set_name)),
                                IF(v_collation_name IS NULL,'',CONCAT(' COLLATE ',v_collation_name )),
                                IF (v_column_comment ='' ,'',CONCAT(' COMMENT ' ,v_column_comment)));

    SELECT  @command;
    PREPARE stmt FROM @command;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    END LOOP;

    CLOSE cur_info_coulumn;
    

SET @OLD_FOREIGN_KEY_CHECKS= @@FOREIGN_KEY_CHECKS; 
SET FOREIGN_KEY_CHECKS=0;
    
    OPEN cur_info_fk;
    SET @command = '';
      
    FOREIGN_KEYS:
    LOOP
        SET no_more_rows = 0;

        FETCH cur_info_fk
        INTO v_table_schema,
             v_index_name,
             v_table_name;

        IF no_more_rows = 1
        THEN
           LEAVE FOREIGN_KEYS;
        END IF;

    
    SET @command = CONCAT('ALTER TABLE ',v_table_schema,'.',v_table_name,' DROP FOREIGN KEY ',v_index_name);
           
    PREPARE stmt FROM @command;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    END LOOP;
    CLOSE cur_info_fk;
    
SET FOREIGN_KEY_CHECKS= @OLD_FOREIGN_KEY_CHECKS;

SET error_code = 0;

END;
