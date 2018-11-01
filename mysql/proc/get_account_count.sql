
-- CALL account.get_account_count (@err,NULL,'TestMSGACCOUNT368850957',NULL,NULL,NULL,@cnt,NULL,NULL,NULL);
-- CALL account.get_account_count (@err,NULL,NULL,NULL,NULL,NULL,@cnt,NULL,NULL,NULL);
-- CALL account.get_account_count (@err,1,'TestMSGACCOUNT368850957',1,1,1,@cnt,123456,1,1);

DROP PROCEDURE IF EXISTS account.get_account_count;

DELIMITER $$
CREATE PROCEDURE account.get_account_count
(
   OUT error_code INT,
    IN in_account_id BIGINT,
    IN in_account_name  VARCHAR(45),
    IN in_fulfillment_type_mask MEDIUMINT,
    IN in_external_seller_id BIGINT,
    IN in_parent_id BIGINT,
   OUT out_count INT,
    IN in_duns BIGINT,
    IN in_account_type_mask MEDIUMINT,
    IN in_active_status_indicator    TINYINT  -- Active vs "all" 1 for active, 0 for all of them)
 )   
BEGIN

SET error_code=-2;

SET @out_count = NULL;

SET @get_q = '
SELECT COUNT(wa.account_id)
  INTO @out_count
  FROM account.account                     wa 
    LEFT OUTER JOIN account.vendor_account va
      ON wa.account_id=va.account_id
    LEFT OUTER JOIN account.account_user   au
      ON (wa.account_id = au.account_id
        AND au.is_owner = 1)
 WHERE 1 = 1 ';

IF in_account_id IS NOT NULL THEN 
  SET @get_q = CONCAT(@get_q,'
    AND wa.account_id = ', in_account_id);
END IF; 

IF in_account_name IS NOT NULL THEN 
  SET @get_q = CONCAT(@get_q,'
    AND wa.account_name_upper like ', '"%', UPPER(in_account_name), '%"');
END IF;

IF in_fulfillment_type_mask IS NOT NULL THEN 
  SET @get_q = CONCAT(@get_q,'
    AND va.fulfillment_type_mask & ', in_fulfillment_type_mask,' <> ','0'); 
END IF;

IF in_external_seller_id IS NOT NULL THEN 
  SET @get_q = CONCAT(@get_q,'
    AND va.external_seller_id  = ', in_external_seller_id);
END IF;

IF in_parent_id IS NOT NULL THEN 
  SET @get_q = CONCAT(@get_q,'
    AND va.parent_id = ', in_parent_id);
END IF; 

IF in_duns IS NOT NULL THEN 
  SET @get_q = CONCAT(@get_q,'    AND va.remit_to_duns  = ', in_duns);
END IF;

IF in_account_type_mask IS NOT NULL THEN 
  SET @get_q = CONCAT(@get_q,'
    AND wa.account_type_mask & ', in_account_type_mask ,' <> ','0');
END IF; 

IF in_active_status_indicator=1 THEN 
  SET @get_q = CONCAT(@get_q,'
    AND wa.account_status = ', in_active_status_indicator);
END IF;

-- select @get_q;

PREPARE stmt FROM @get_q;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET out_count = @out_count;

SET error_code = 0;

END$$
DELIMITER ;