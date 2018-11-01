
-- call account.get_user_accounts (@err, 123, 1);
-- call account.get_user_accounts (@err, null, 1);
-- call account.get_user_accounts (@err, 123, null);
-- call account.get_user_accounts (@err, null, null);

DROP PROCEDURE IF EXISTS account.get_user_accounts;

DELIMITER $$
CREATE PROCEDURE account.get_user_accounts(OUT error_code INT
                                           ,IN user_id_in BIGINT
                                           ,IN account_id_in BIGINT)
                                                                                 
BEGIN

SET error_code = -2;
 
SELECT  au.account_user_id,
        au.account_id, 
        au.is_owner, 
        au.account_user_status, 
        au.modified_dtm modified_dtm, 
        au.created_dtm created_dtm,
        a.account_name, 
        a.account_status, 
        a.account_web_domain,
        a.account_email_addr,
        va.fulfillment_type_mask,
        au.token,
        au.token_expiration_date,
        va.remit_to_duns,
        va.description,
        va.vid vendor_id,
        au.user_id,
        va.channel_mask,
        a.account_type_mask
  FROM  account.account_user                    au, 
        account.account                         a
        LEFT OUTER JOIN  account.vendor_account va
          ON a.account_id = va.account_id
 WHERE au.account_id = a.account_id
   AND au.user_id = IFNULL (user_id_in, au.user_id)
   AND au.account_id = IFNULL (account_id_in, au.account_id)
   AND au.account_user_status = 1
ORDER BY a.account_name;
        
SET error_code=0;        

END$$
DELIMITER ;
