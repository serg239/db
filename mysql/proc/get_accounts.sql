
-- CALL account.get_accounts (@err,NULL,'TestMSGACCOUNT368850957',NULL,NULL,NULL, NULL, NULL, null,NULL,0);
-- CALL account.get_accounts (@err,NULL,NULL,NULL,NULL,NULL, NULL, NULL,NULL,8,NULL);

DROP PROCEDURE IF EXISTS account.get_accounts;

DELIMITER $$
CREATE PROCEDURE account.get_accounts
(
    OUT error_code INT,
    IN in_account_id BIGINT,
    IN in_account_name  VARCHAR(45),
    IN in_fulfillment_type_mask MEDIUMINT,
    IN in_external_seller_id BIGINT,
    IN in_parent_id BIGINT,
    IN in_starting_position INT,
    IN in_page_size INT,
    IN in_duns BIGINT,
    IN in_account_type_mask MEDIUMINT,
    IN in_active_status_indicator    TINYINT  -- Active vs "all" 1 for active, 0 for all of them
)
BEGIN

SET error_code=-2;

SET @get_q = '
SELECT a.account_id,
       a.account_name,
       a.account_status,
       a.account_web_domain,
       a.account_email_addr,
       va.fulfillment_type_mask,
       va.external_seller_id,
       va.parent_id,
       au.user_id,
       a.modified_id,
       a.modified_dtm,
       a.created_dtm,
       va.remit_to_duns,
       va.vid,
       va.description,
       va.channel_mask,
       a.account_type_mask
  FROM account.account a
       LEFT OUTER JOIN account.vendor_account va
         ON a.account_id = va.account_id
       LEFT OUTER JOIN  account.account_user  au
         ON (a.account_id = au.account_id
           AND au.is_owner = 1)
 WHERE 1 = 1 ';

IF in_account_id IS NOT NULL THEN 
  SET @get_q = CONCAT(@get_q,'
    AND a.account_id = ', in_account_id);
END IF; 

IF in_account_name IS NOT NULL THEN 
  SET @get_q = CONCAT(@get_q,'
    AND a.account_name_upper like ', '"', UPPER(in_account_name), '%"');
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
    AND a.account_type_mask & ', in_account_type_mask ,' <> ','0');
END IF; 

IF in_active_status_indicator=1 THEN 
  SET @get_q = CONCAT(@get_q,'
    AND a.account_status = ', in_active_status_indicator);
END IF;

SET @get_q = CONCAT(@get_q, ' ORDER BY a.account_name');


IF (in_starting_position IS NOT NULL) AND (in_page_size IS NOT NULL) THEN
  SET @get_q = CONCAT(@get_q, ' LIMIT ', in_starting_position, ', ', in_page_size);    
END IF;

-- SELECT @get_q;

PREPARE stmt FROM @get_q;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET error_code = 0;

END$$
DELIMITER ;
