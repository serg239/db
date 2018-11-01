-- call account.get_user_accounts (@err, 123, 2);
-- call account.get_user_accounts (@err, null, 1);
-- call account.get_user_accounts (@err, 123, null);
-- call account.get_user_accounts (@err, null, null);

DROP PROCEDURE IF EXISTS account.get_user_accounts;

DELIMITER $$
CREATE PROCEDURE account.get_user_accounts(OUT error_code INT, IN user_id_in BIGINT, IN account_id_in BIGINT)
                                                                                 
BEGIN

SET error_code = -2;

SELECT au.account_user_id,
       au.account_id, 
       au.is_owner, 
       au.account_user_status, 
       au.modified_dtm modified_dtm, 
       au.created_dtm created_dtm,
       wa.account_name, 
       wa.account_status, 
       wa.account_web_domain,
       wa.account_email_addr,
       wa.account_type_mask,
       au.token,
       au.token_expiration_date,
       wa.duns,
       wa.description,
       wa.vid vendor_id,
       au.user_id,
       wa.channel_mask,
       account.get_pending_acknowledgment(wa.account_id, wa.account_type_mask) AS pending_acknowledgment
  FROM account.account_user  au, 
       account.web_account   wa
 WHERE au.account_id = wa.account_id
   AND au.user_id = IFNULL (user_id_in, au.user_id)
   AND au.account_id = IFNULL (account_id_in, au.account_id)
ORDER BY wa.account_name;
        
SET error_code=0;        

END$$
DELIMITER ;
