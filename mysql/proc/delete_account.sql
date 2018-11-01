
-- call account.delete_account ();

DROP PROCEDURE IF EXISTS account.delete_account;

DELIMITER $$
CREATE PROCEDURE account.delete_account ()
BEGIN

DECLARE c_status mediumint(9) DEFAULT 2; -- pending status
 
DROP TABLE IF EXISTS account.temp_delete_account;
CREATE TABLE account.temp_delete_account
AS
SELECT account_id 
  FROM account.account
 WHERE account_id IN 
      (SELECT wa.account_id
         FROM account.account wa, account_user au 
        WHERE wa.account_id = au.account_id
          AND wa.account_status = c_status
          AND au.account_user_status = c_status
          AND NOW() > DATE_ADD(au.token_expiration_date, INTERVAL 2 DAY))
          AND account_id NOT IN 
           (SELECT wa.account_id
              FROM account wa, account_user au
             WHERE wa.account_id = au.account_id
            -- AND wa.account_status = c_status
              AND au.account_user_status <> c_status);

DELETE FROM account.account 
 WHERE account_id IN 
   (SELECT account_id
      FROM account.temp_delete_account
    );

DELETE 
  FROM account.account_user 
 WHERE account_user_status = c_status
   AND NOW() > DATE_ADD(token_expiration_date, INTERVAL 2 DAY); 
   
DROP TABLE IF EXISTS account.temp_delete_account;

END$$
DELIMITER ;
