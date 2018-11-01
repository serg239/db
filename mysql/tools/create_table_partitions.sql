DROP PROCEDURE IF EXISTS mysql.create_table_partitions;

CREATE PROCEDURE mysql.`create_table_partitions`(
  out ERROR_CODE     INT,
  number_of_month_in INT,
  schema_in          VARCHAR(50),
  table_in           VARCHAR(50)
)
BEGIN
  DECLARE part_month      INT;
  DECLARE part_month_name INT;
  DECLARE part_year       INT;
  DECLARE i               INT;
  DECLARE partExists      INT;
  DECLARE days            INT;
  DECLARE actual_month    VARCHAR(2);
  
  SET ERROR_CODE = -2;
  
  SELECT month(now()), year(now()) INTO  part_month_name, part_year FROM dual;
  
  IF (part_month_name = 12) THEN
    SET part_year = part_year + 1;
    SET part_month = 1;
  ELSE 
    SET part_month = part_month_name + 1;
  END IF;

  
  SET @max_date = 0;
  SELECT TO_DAYS(STR_TO_DATE('1.1.2031', '%d.%m.%Y')) INTO @max_date FROM dual;
  
  set i = 1;
  add_part_loop: loop

    IF i > number_of_month_in THEN
      LEAVE add_part_loop;
    END IF;
    
    SELECT COUNT(1) INTO partExists
      FROM information_schema.partitions
     WHERE table_schema = schema_in 
       AND table_name = table_in
       AND partition_name = CONCAT('part_', lpad(part_month_name, 2, '0'), '_', part_year);
    
    IF (partExists = 0) THEN
      SELECT TO_DAYS(STR_TO_DATE(CONCAT('1.', part_month, '.', part_year), '%d.%m.%Y')) INTO days FROM dual;
      SET @q = CONCAT(
            'ALTER TABLE ', schema_in, '.' , table_in, ' REORGANIZE PARTITION part_12_2030 INTO 
              (PARTITION part_', lpad(part_month_name, 2, '0'), '_', part_year, ' VALUES LESS THAN (',
                  TO_DAYS(STR_TO_DATE(CONCAT('1.', part_month, '.', part_year), '%d.%m.%Y')),
                  '), 
               PARTITION part_12_2030 VALUES LESS THAN (', @max_date, '))');
      
       PREPARE stmt from @q;
       EXECUTE stmt;
       DEALLOCATE PREPARE stmt;
    END IF;
    
    SET i = i + 1;
    
    SET part_month_name = part_month_name + 1;
  
    IF (part_month_name = 12) THEN
      SET part_year = part_year + 1;
      SET part_month = 1;
    ELSE 
      SET part_month = part_month_name + 1;
    END IF;
    
  END LOOP add_part_loop;
  
  SET ERROR_CODE = 0;
  
END;
