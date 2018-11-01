
-- call account.get_account_address(@err, 1);

DROP PROCEDURE IF EXISTS account.get_account_address;

DELIMITER $$

CREATE PROCEDURE account.get_account_address(OUT error_code INT
                                             ,IN in_account_id BIGINT)
   BEGIN   
   
   SET error_code = -2;
 
   SELECT a.address_name,
          a.street_1,
          a.street_2,
          a.street_3,
          a.city,
          a.postal_code,
          a.state_province,
          a.country,
          aa.account_address_id,
          aa.account_id,
          aa.account_address_type_cd, 
          aa.account_address_phone,
          aa.account_address_phone_ext,
          aa.account_address_fax,
          aa.account_address_email,
          aa.account_address_first_name,
          aa.account_address_last_name,
          aa.account_address_business_name,
          aa.account_address_status,
          a.longitude,
          a.latitude
     FROM account.address         a,
          account.account_address aa
    WHERE aa.address_id = a.address_id 
      AND aa.account_address_status <> 0
      AND aa.account_id = in_account_id;
      
   SET error_code = 0; 
         
   END
$$

DELIMITER ;
