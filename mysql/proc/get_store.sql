-- CALL account.get_store(@err,2,1,'sname123',1 ,1);
-- CALL account.get_store(@err,2,NULL,NULL,NULL,NULL);

DELIMITER $$

DROP PROCEDURE IF EXISTS account.get_store$$

CREATE PROCEDURE account.get_store(OUT error_code INT
                                   ,IN in_account_id BIGINT
                                   ,IN in_external_store_id VARCHAR(20)
                                   ,IN in_store_name VARCHAR(45)
                                   ,IN in_account_store_id BIGINT
                                   ,IN in_store_type_id INT)
BEGIN

SET error_code=-2;

SET @q = CONCAT('
SELECT acs.account_store_id,
       acs.account_id,
       acs.external_store_id, 
       s.store_name, 
       s.modified_id, 
       s.modified_dtm, 
       s.created_dtm, 
       s.store_type_id,
       s.time_zone
  FROM account.store s,
       account.account_store acs
 WHERE operational_status = 1 
   AND acs.store_id=s.store_id
   AND acs.account_id = ', in_account_id);
 
 IF in_external_store_id IS NOT NULL THEN
 SET @q = CONCAT(@q,' AND acs.external_store_id = ','"',in_external_store_id,'"');
 END IF;
 
 IF in_store_name IS NOT NULL THEN
 SET @q = CONCAT(@q,' AND store_name = ','"',in_store_name,'"');
 END IF;
 
 IF in_account_store_id IS NOT NULL THEN
 SET @q = CONCAT(@q,' AND acs.account_store_id = ',in_account_store_id);
 END IF;
 
 IF in_store_type_id IS NOT NULL THEN
 SET @q = CONCAT(@q,' AND store_type_id = ',in_store_type_id);
 END IF; 
 
 PREPARE stmt FROM @q;
 EXECUTE stmt;
 DEALLOCATE PREPARE stmt;
 
SET error_code=0;

END$$
DELIMITER ;
