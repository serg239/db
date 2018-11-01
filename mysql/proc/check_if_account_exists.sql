-- call account.check_if_account_name_exists (@err, 'Lacoste');

DROP PROCEDURE IF EXISTS account.check_if_account_name_exists;

DELIMITER $$
CREATE PROCEDURE account.check_if_account_name_exists(OUT error_code INT
                                                      ,IN in_account_name VARCHAR(45))
    
BEGIN

SET error_code=-2; 

SELECT account_id
  FROM account.account
 WHERE account_name_upper = UPPER(in_account_name);

SET error_code = 0;

END$$
DELIMITER ;

