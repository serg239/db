/*
  Version:
    2011.11.12.01
  Script:
    00_create_func_initcap.sql
  Description:
    Capitalize initial letters of each word in the string.
  Input:
    string_in_out
  Output:
    Result string
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\00_create_func_initcap.sql
  Usage:
    SET @table_name = 'content_item_build_instruction';
    SELECT elt.initcap(REPLACE(@table_name, "_", " ")) AS t_name;
  Result:  
    +--------------------------------+
    | t_name                         |
    +--------------------------------+
    | Content Item Build Instruction |
    +--------------------------------+
*/
DELIMITER $$

DROP FUNCTION IF EXISTS elt.initcap$$ 

CREATE FUNCTION elt.initcap
(
  string_in_out  VARCHAR(255)
) 
RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN 
  DECLARE str_len INTEGER; 
  DECLARE i       INTEGER; 
  SET str_len       = CHAR_LENGTH(string_in_out); 
  SET string_in_out = LOWER(string_in_out); 
  SET i = 0;
  WHILE (i < str_len) DO 
    IF (MID(string_in_out, i, 1) = ' ' OR i = 0) THEN 
      IF (i < str_len) THEN 
        SET string_in_out = CONCAT(LEFT(string_in_out, i), 
                                   UPPER(MID(string_in_out, i + 1, 1)), 
                                   RIGHT(string_in_out, str_len - i - 1) 
                                  ); 
      END IF; 
    END IF; 
    SET i = i + 1; 
  END WHILE; 
  RETURN string_in_out;
END$$ 

DELIMITER ; 

SELECT '====> Function ''initcap'' has been created' AS "Info:" FROM dual;
