
-- call account.edit_account (@err, -1, 2, 'account_name222_in', 'account_web_domain_in', 'account_email_addr_in', 1,6,987123,897,'new seller description',1);

DROP PROCEDURE IF EXISTS account.edit_account;

DELIMITER $$
CREATE PROCEDURE account.edit_account(OUT error_code INT
                                     ,IN app_user_id_in BIGINT
                                     ,IN account_id_in BIGINT
                                     ,IN account_name_in VARCHAR(45)
                                     ,IN account_web_domain_in VARCHAR(200)
                                     ,IN account_email_addr_in VARCHAR(100)
                                     ,IN account_status_in MEDIUMINT
                                     ,IN fulfillment_type_mask_in MEDIUMINT
                                     ,IN remit_to_duns_in BIGINT
                                     ,IN vid_in CHAR(3)
                                     ,IN description_in VARCHAR(2500),
                                      IN channel_mask_in MEDIUMINT
)

BEGIN

MAIN_OUTER:BEGIN

-- Check on account_mask validity - pretty weird way of check constraint implementation

SET error_code = -2;
 
IF IFNULL(fulfillment_type_mask_in,1) <= 0    -- NULL is a valid input for this API, arrrrggghhhhhh!!!!
THEN
SET error_code=-3;
LEAVE MAIN_OUTER;
END IF;  

UPDATE account.account 
   SET account_name        = IFNULL(account_name_in, account_name), 
       account_email_addr  = IFNULL(account_email_addr_in, account_email_addr),
       account_web_domain  = IFNULL(account_web_domain_in, account_web_domain),
       account_status      = IFNULL(account_status_in, account_status),        
       modified_id         = app_user_id_in
 WHERE account_id = account_id_in;
       
UPDATE account.vendor_account 
   SET fulfillment_type_mask = IFNULL(fulfillment_type_mask_in,fulfillment_type_mask),
       vid                   = IFNULL(vid_in,vid),
       description           = IFNULL(description_in,description),
       channel_mask          = IFNULL(channel_mask_in,channel_mask),
       remit_to_duns         = IFNULL(remit_to_duns_in,remit_to_duns)
 WHERE account_id = account_id_in;
      
END MAIN;
        
SET error_code=0;  

END MAIN_OUTER;

END$$
DELIMITER ;
