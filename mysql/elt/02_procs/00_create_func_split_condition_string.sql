/*
  Version:
    2011.11.12.01
  Script:
    00_create_func_split_condition_string.sql
  Description:
    Split string.
  Input:
    entry_name_in           - Table or column name
    in_table_list_in        - List of tables for IN clause
    not_in_table_list_in    - List of tables for NOT IN clause
    like_table_list_in      - List of tables for LIKE clause
    not_like_table_list_in  - List of tables for NOT LIKE clause
    delimiter_in            - List's separator - any value, for instance [',' | ';' | ... ]
  Output:
    Result string
  Install:
    mysql -h <db_name> -u <db_user_name> -p<db_user_pwd> < <path_to_file>\00_create_func_split_condition_string.sql
  Usage #1:
    SELECT elt.split_condition_string ('table_name', NULL, NULL, 'account; account_log', 'account_address_%; %_messages', ';') AS cond FROM dual;
  Result:
    +---------------------------------------------------------------------------------------------------------------------------------------------------+
    | cond                                                                                                                                              |
    +---------------------------------------------------------------------------------------------------------------------------------------------------+
    |  AND table_name LIKE 'account' AND table_name LIKE 'account_log' AND table_name NOT LIKE 'account_address_%' AND table_name NOT LIKE '%_messages' |
    +---------------------------------------------------------------------------------------------------------------------------------------------------+

  Usage #2:
    SELECT elt.split_condition_string ('table_name', NULL, 'account; account_log', NULL, NULL, ';') AS cond FROM dual;
  Result:
    +--------------------------------------------------+
    | cond                                             |
    +--------------------------------------------------+
    | AND table_name NOT IN ('account', 'account_log') |
    +--------------------------------------------------+

  Usage #3:
    SELECT elt.split_condition_string ('table_name', 'account; account_log', NULL, NULL, NULL, ';') AS cond FROM dual;
  Result:
    +----------------------------------------------+
    | cond                                         |
    +----------------------------------------------+
    | AND table_name IN ('account', 'account_log') |
    +----------------------------------------------+

  Usage #4:
    SELECT elt.split_condition_string ('table_name', 'account; account_log', NULL, 'user; user_log', 'user_%; account_user_%', ';') AS cond FROM dual;
  Result:
    +----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    | cond                                                                                                                                                                             |
    +----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
    | AND table_name IN ('account', 'account_log') AND table_name LIKE 'user' AND table_name LIKE 'user_log' AND table_name NOT LIKE 'user_%' AND table_name NOT LIKE 'account_user_%' |
    +----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
*/
DELIMITER $$ 

DROP FUNCTION IF EXISTS elt.split_condition_string$$ 

CREATE FUNCTION elt.split_condition_string
(
  entry_name_in          VARCHAR(64),   -- table or column name
  in_table_list_in       TEXT,
  not_in_table_list_in   TEXT,
  like_table_list_in     TEXT,
  not_like_table_list_in TEXT,
  delimiter_in           VARCHAR(10)    -- any values, for instance [',' | ';' | ... ]
) 
RETURNS TEXT(10000) CHARSET utf8
NO SQL 
BEGIN 

  DECLARE v_delimiter_pos  INTEGER; 
  DECLARE v_reminder_str   TEXT; 
  DECLARE v_reminder_len   INTEGER; 
  DECLARE v_curr_substr    TEXT         DEFAULT ''; 
  DECLARE v_out_text       TEXT(10000)  DEFAULT ''; 

  -- Insert each split variable into the temp string
  SET v_out_text = '';

  -- IN clause
  IF (in_table_list_in IS NOT NULL) THEN
  
    SET v_reminder_str = in_table_list_in;
    --
    SET v_reminder_len = LENGTH(in_table_list_in);
    -- Find the first instance of the spliting character
    SET v_delimiter_pos = LOCATE(delimiter_in, v_reminder_str); 
  
    WHILE v_reminder_len > 0 DO 

      IF v_delimiter_pos = 0 THEN 
        SET v_curr_substr = TRIM(v_reminder_str); 
        SET v_reminder_str  = ''; 
        SET v_reminder_len  = 0; 
      ELSE 
        SET v_curr_substr  = TRIM(SUBSTRING(v_reminder_str, 1, v_delimiter_pos - 1)); 
        SET v_reminder_str = TRIM(SUBSTRING(v_reminder_str FROM v_delimiter_pos + 1)); 
        SET v_reminder_len = LENGTH(v_reminder_str);
      END IF; 

      IF (v_curr_substr != '') THEN 
        SET v_out_text = CONCAT(v_out_text, CHAR(39), v_curr_substr, CHAR(39), ', ');
      END IF; 

      SET v_delimiter_pos = LOCATE(delimiter_in, v_reminder_str); 

    END WHILE; 
  
    SET v_out_text = CONCAT('AND ', entry_name_in, ' IN (', TRIM(TRAILING ', ' FROM v_out_text), ')');

  END IF;

  -- NOT IN clause
  IF (not_in_table_list_in IS NOT NULL) THEN
  
    SET v_reminder_str = not_in_table_list_in;
    --
    SET v_reminder_len = LENGTH(not_in_table_list_in);
    -- Find the first instance of the spliting character
    SET v_delimiter_pos = LOCATE(delimiter_in, v_reminder_str); 
  
    WHILE v_reminder_len > 0 DO 

      IF v_delimiter_pos = 0 THEN 
        SET v_curr_substr = TRIM(v_reminder_str); 
        SET v_reminder_str  = ''; 
        SET v_reminder_len  = 0; 
      ELSE 
        SET v_curr_substr  = TRIM(SUBSTRING(v_reminder_str, 1, v_delimiter_pos - 1)); 
        SET v_reminder_str = TRIM(SUBSTRING(v_reminder_str FROM v_delimiter_pos + 1)); 
        SET v_reminder_len = LENGTH(v_reminder_str);
      END IF; 

      IF (v_curr_substr != '') THEN 
        SET v_out_text = CONCAT(v_out_text, CHAR(39), v_curr_substr, CHAR(39), ', ');
      END IF; 

      SET v_delimiter_pos = LOCATE(delimiter_in, v_reminder_str); 

    END WHILE; 
  
    SET v_out_text = CONCAT('AND ', entry_name_in, ' NOT IN (', TRIM(TRAILING ', ' FROM v_out_text), ')');

  END IF;

  -- LIKE clause
  IF (like_table_list_in IS NOT NULL) THEN
  
    SET v_reminder_str = like_table_list_in;
    --
    SET v_reminder_len = LENGTH(like_table_list_in);
    -- Find the first instance of the spliting character
    SET v_delimiter_pos = LOCATE(delimiter_in, v_reminder_str); 
  
    WHILE v_reminder_len > 0 DO

      IF v_delimiter_pos = 0 THEN 
        SET v_curr_substr = TRIM(v_reminder_str); 
        SET v_reminder_str  = ''; 
        SET v_reminder_len  = 0; 
      ELSE 
        SET v_curr_substr  = TRIM(SUBSTRING(v_reminder_str, 1, v_delimiter_pos - 1)); 
        SET v_reminder_str = TRIM(SUBSTRING(v_reminder_str FROM v_delimiter_pos + 1)); 
        SET v_reminder_len = LENGTH(v_reminder_str);
      END IF; 

      IF (v_curr_substr != '') THEN 
        SET v_out_text = CONCAT(v_out_text, ' AND ', entry_name_in, ' LIKE ', CHAR(39), v_curr_substr, CHAR(39));
      END IF; 

      SET v_delimiter_pos = LOCATE(delimiter_in, v_reminder_str); 

    END WHILE; 
  
  END IF;

  -- NOT LIKE clause
  IF (not_like_table_list_in IS NOT NULL) THEN
  
    SET v_reminder_str = not_like_table_list_in;
    --
    SET v_reminder_len = LENGTH(not_like_table_list_in);
    -- Find the first instance of the spliting character
    SET v_delimiter_pos = LOCATE(delimiter_in, v_reminder_str); 
  
    WHILE v_reminder_len > 0 DO
      IF v_delimiter_pos = 0 THEN 
        SET v_curr_substr = TRIM(v_reminder_str); 
        SET v_reminder_str  = ''; 
        SET v_reminder_len  = 0; 
      ELSE 
        SET v_curr_substr  = TRIM(SUBSTRING(v_reminder_str, 1, v_delimiter_pos - 1)); 
        SET v_reminder_str = TRIM(SUBSTRING(v_reminder_str FROM v_delimiter_pos + 1)); 
        SET v_reminder_len = LENGTH(v_reminder_str);
      END IF; 
      IF (v_curr_substr != '') THEN 
        SET v_out_text = CONCAT(v_out_text, ' AND ', entry_name_in, ' NOT LIKE ', CHAR(39), v_curr_substr, CHAR(39));
      END IF; 
      SET v_delimiter_pos = LOCATE(delimiter_in, v_reminder_str); 
    END WHILE; 
  
  END IF;
  
  RETURN v_out_text; 

END$$ 

DELIMITER ;

SELECT '====> Function ''split_condition_string'' has been created' AS "Info:" FROM dual;
