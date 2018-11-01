/*
  Version:
    2011.11.12.01
  Script:
    00_create_func_translate.sql
  Description:
    Translate characters in the string.
  Input:
    string_in_out
    from_chars_in
    to_chars_in
  Output:
    Result string
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\00_create_func_translate.sql
  Usage:
    SET @table_name = 'content_item_build_instruction';
    SELECT LOWER(elt.translate(elt.initcap(REPLACE(@table_name, "_", " ")), 
                               "ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz", 
                               "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                ) AS table_alias
      FROM dual;               
  Result:  
    +-------------+
    | table_alias |
    +-------------+
    | cibi        |
    +-------------+
*/
DELIMITER $$

DROP FUNCTION IF EXISTS elt.translate$$

SET NAMES utf8$$
 
CREATE FUNCTION elt.translate
(
  string_in_out  VARCHAR(255), 
  from_chars_in  VARCHAR(255),
  to_chars_in    VARCHAR(255)
)
RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
  DECLARE i INTEGER;
  SET i = CHAR_LENGTH(from_chars_in);
 
  WHILE i > 0 DO
    SET string_in_out = REPLACE(string_in_out,
                                SUBSTR(from_chars_in, i, 1),
                                SUBSTR(to_chars_in, i, 1)
                               );
   SET i = i - 1;
  END WHILE;
  RETURN string_in_out;
END$$

DELIMITER ;

SELECT '====> Function ''translate'' has been created' AS "Info:" FROM dual;
