-- This API is used to publish TW items
-- call catalog.publish_tw_items(@err, '5', 98);
-- call catalog.publish_tw_items(@err, '1, 2, 3', 1);

DELIMITER $$

DROP PROCEDURE IF EXISTS catalog.publish_tw_items$$

CREATE PROCEDURE catalog.publish_tw_items(
    OUT error_code INT,
     IN item_id_in TEXT,    
     IN modified_id_in BIGINT
)
exec:BEGIN

SET error_code = -2;
        
IF item_id_in IS NULL OR modified_id_in IS NULL THEN
  SET error_code = -3;
  LEAVE exec;
END IF;  


-- first call allocate...
CALL catalog.allocate_tw_items(error_code, item_id_in, modified_id_in);
 
-- then the publish
SET @q = CONCAT(' UPDATE catalog.item i
                     SET i.catalog_status = 2 -- published status
                        ,i.modified_id = ', modified_id_in, '      
                   WHERE i.item_id IN (', item_id_in, ')      
              ');
  
IF @debug_api_mode = 1 THEN
  SELECT CAST(@q AS CHAR) AS debug_sql;
ELSE
  PREPARE stmt FROM @q;
  EXECUTE stmt;
  DEALLOCATE PREPARE stmt;
END IF;    
          
SET error_code = 0;

END$$

DELIMITER ;
