-- This API is used to get hierarchy
-- Output: error_code.
-- Error codes: 0 (Success), -2 (Error)
-- call catalog.get_store_hierarchy(@err, '144501,144601', 0, 2, '003');

DELIMITER $$

DROP PROCEDURE IF EXISTS catalog.get_store_hierarchy$$

CREATE PROCEDURE catalog.get_store_hierarchy(
    OUT error_code INT,
     IN store_hierarchy_id_list_in TEXT,
     IN parent_store_hierarchy_id_in BIGINT(20),
     IN store_id_in SMALLINT,
     IN external_hierarchy_id_path_in VARCHAR(128)
)
BEGIN

  SET error_code = -2;
  
  SET @q = CONCAT(' 
    SELECT sh.store_hierarchy_id,
           sh.store_hierarchy_name,
           sh.store_id,
           sh.parent_store_hierarchy_id,
           sh.external_hierarchy_id,
           sh.store_hierarchy_display_path,
           sh.store_hierarchy_id_path,
           IFNULL((SELECT 1 
                     FROM semistatic_content.store_hierarchy shref 
                    WHERE shref.parent_store_hierarchy_id = sh.store_hierarchy_id 
                    LIMIT 1), 0) AS has_children,
           sh.status,
           sh.modified_id,
           sh.created_dtm,
           sh.modified_dtm,
           sh.external_hierarchy_id_path,
           sh.store_hierarchy_line_type_mask
    FROM semistatic_content.store_hierarchy sh
   WHERE sh.store_hierarchy_id <> 0 ' 
    , IF(store_hierarchy_id_list_in IS NOT NULL, CONCAT(' AND sh.store_hierarchy_id IN (', store_hierarchy_id_list_in, ')'), '')
    , IF(parent_store_hierarchy_id_in IS NOT NULL, CONCAT(' AND sh.parent_store_hierarchy_id = ', parent_store_hierarchy_id_in), '')
    , IF(store_id_in IS NOT NULL, CONCAT(' AND sh.store_id = ', store_id_in), '')
    , IF(external_hierarchy_id_path_in IS NOT NULL, CONCAT(' AND sh.external_hierarchy_id_path = ', QUOTE(external_hierarchy_id_path_in)), '')
    , ' ORDER BY cast(sh.external_hierarchy_id AS unsigned) '
  );
  
  -- check for session variable that has been set outside of 
  IF @debug_api_mode = 1 THEN
    SELECT CAST(@q AS CHAR) AS debug_sql;
  ELSE
    PREPARE query FROM @q;
    EXECUTE query;
    DEALLOCATE PREPARE query;  
  END IF;
    
  SET error_code = 0;

END$$

DELIMITER ;
