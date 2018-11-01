
-- call account.get_account_status(@err, 123, @oaccstatus);


DROP PROCEDURE IF EXISTS account.get_account_status;

DELIMITER $$
CREATE PROCEDURE account.get_account_status(OUT error_code         INT, 
                                             IN account_id_in      BIGINT,
                                            OUT account_status_out INT)
BEGIN

SET error_code = -2;

 SELECT wa.account_status
   INTO account_status_out
   FROM account.web_account wa
  WHERE wa.account_id = account_id_in
  ;
 
 SET error_code = 0;
    
END$$
DELIMITER ;
